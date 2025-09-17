#include "clipper2_open.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/geometry2d.hpp>
#include <cmath>
#include <vector>
#include "clipper2/clipper.h"

using namespace godot;

void Clipper2Open::_bind_methods() {
    ClassDB::bind_method(
        D_METHOD("intersect_polyline_with_polygon_deterministic", "polyline", "polygon", "epsilon"),
        &Clipper2Open::intersect_polyline_with_polygon_deterministic,
        DEFVAL(0.0)
    );

    ClassDB::bind_method(
        D_METHOD("intersect_many_polyline_with_polygon_deterministic", "polylines", "polygon", "epsilon"),
        &Clipper2Open::intersect_many_polyline_with_polygon_deterministic,
        DEFVAL(0.0)
    );

    ClassDB::bind_method(
        D_METHOD("intersect_polygons_batched", "polygons", "subject_polygon"),
        &Clipper2Open::intersect_polygons_batched
    );

    ClassDB::bind_method(
        D_METHOD("intersect_many_polylines_with_polygons", "polylines", "polygons"),
        &Clipper2Open::intersect_many_polylines_with_polygons
    );

    ClassDB::bind_method(
        D_METHOD("difference_many_polylines_with_polygons", "polylines", "polygons"),
        &Clipper2Open::difference_many_polylines_with_polygons
    );

    ClassDB::bind_method(
        D_METHOD("intersect_many_ringpolylines_with_polygons", "polylines", "polygons"),
        &Clipper2Open::intersect_many_ringpolylines_with_polygons
    );
}

// Utility: assert no consecutive identical points
static void assert_no_identical_points(const PackedVector2Array &points, const char *label) {
    for (int i = 0; i < points.size() - 1; i++) {
        if (points[i] == points[i + 1]) {
            ERR_FAIL_MSG(vformat("Sanity check failed: identical consecutive points in %s at index %d", label, i));
        }
    }
    if (points.size() > 2 && points[0] == points[points.size() - 1]) {
        ERR_FAIL_MSG(vformat("Sanity check failed: first and last points in %s are identical", label));
    }
}

static bool overlap_segment(const Vector2 &a, const Vector2 &b,
    const Vector2 &c, const Vector2 &d,
    double eps,
    Vector2 &out1, Vector2 &out2) {
Vector2 ab = b - a;
Vector2 cd = d - c;

// Reject degenerate segments
double len_ab = ab.length();
double len_cd = cd.length();
if (len_ab == 0.0 || len_cd == 0.0) return false;

// Require the segment to lie on (or very near) the same line as  c
double dist_a = std::abs((a - c).cross(cd)) / len_cd;
double dist_b = std::abs((b - c).cross(cd)) / len_cd;
if (dist_a > eps || dist_b > eps) return false;

// --- Project & intersect along cd (polygon edge) instead of ab ---
Vector2 v = cd / len_cd;           // unit direction along cd
double s0 = 0.0;                   // cd starts at c
double s1 = len_cd;                // cd ends at d
double sa = (a - c).dot(v);        // a's coordinate along cd
double sb = (b - c).dot(v);        // b's coordinate along cd
if (sa > sb) std::swap(sa, sb);    // ensure sa <= sb

double lo = std::max(s0, sa);
double hi = std::min(s1, sb);
if (hi <= lo) return false;

// Construct overlap endpoints along cd
out1 = c + v * lo;
out2 = c + v * hi;

// Normalize orientation: ensure out1 is closer to a
if (a.distance_to(out2) < a.distance_to(out1)) {
std::swap(out1, out2);
}

return true;
}

// --- Single polyline version ---
Array Clipper2Open::intersect_polyline_with_polygon_deterministic(
    const PackedVector2Array &polyline,
    const PackedVector2Array &polygon,
    double epsilon) const
{
    assert_no_identical_points(polyline, "polyline");
    assert_no_identical_points(polygon, "polygon");

    Array result;
    if (polyline.size() < 2 || polygon.size() < 2) {
        return result;
    }

    PackedVector2Array current_chain;

    for (int i = 0; i < polyline.size() - 1; i++) {
        Vector2 a = polyline[i];
        Vector2 b = polyline[i + 1];
        bool overlapped = false;
        Vector2 o1, o2;

        for (int j = 0; j < polygon.size(); j++) {
            Vector2 c = polygon[j];
            Vector2 d = polygon[(j + 1) % polygon.size()];

            if (overlap_segment(a, b, c, d, epsilon, o1, o2)) {
                overlapped = true;
                break;
            }
        }

        if (overlapped) {
            if (current_chain.size() == 0) {
                current_chain.append(o1);
                current_chain.append(o2);
            } else {
                Vector2 first = current_chain[0];
                Vector2 last  = current_chain[current_chain.size() - 1];

                if (last.distance_to(o1) <= epsilon) {
                    current_chain.append(o2);
                } else if (last.distance_to(o2) <= epsilon) {
                    current_chain.append(o1);
                } else if (first.distance_to(o1) <= epsilon) {
                    current_chain.insert(0, o2);
                } else if (first.distance_to(o2) <= epsilon) {
                    current_chain.insert(0, o1);
                } else {
                    result.append(current_chain);
                    current_chain = PackedVector2Array();
                    current_chain.append(o1);
                    current_chain.append(o2);
                }
            }
        } else {
            if (current_chain.size() > 0) {
                result.append(current_chain);
                current_chain = PackedVector2Array();
            }
        }
    }

    if (current_chain.size() > 0) {
        result.append(current_chain);
    }

    return result;
}

// --- Batched version ---
Array Clipper2Open::intersect_many_polyline_with_polygon_deterministic(
    const Array &polylines,
    const PackedVector2Array &polygon,
    double epsilon) const
{
    assert_no_identical_points(polygon, "polygon");

    Array results;
    results.resize(polylines.size());

    if (polygon.size() < 2) {
        return results;
    }

    // Precompute polygon edges
    struct Edge { Vector2 c, d; };
    std::vector<Edge> edges;
    edges.reserve(polygon.size());
    for (int j = 0; j < polygon.size(); j++) {
        edges.push_back({polygon[j], polygon[(j + 1) % polygon.size()]});
    }

    for (int idx = 0; idx < polylines.size(); idx++) {
        PackedVector2Array line_in = polylines[idx];
        Array result;
        if (line_in.size() < 2) {
            results[idx] = result;
            continue;
        }

        PackedVector2Array current_chain;

        for (int i = 0; i < line_in.size() - 1; i++) {
            Vector2 a = line_in[i];
            Vector2 b = line_in[i + 1];
            bool overlapped = false;
            Vector2 o1, o2;

            for (const auto &edge : edges) {
                if (overlap_segment(a, b, edge.c, edge.d, epsilon, o1, o2)) {
                    overlapped = true;
                    break;
                }
            }

            if (overlapped) {
                if (current_chain.size() == 0) {
                    current_chain.append(o1);
                    current_chain.append(o2);
                } else {
                    Vector2 first = current_chain[0];
                    Vector2 last  = current_chain[current_chain.size() - 1];

                    if (last.distance_to(o1) <= epsilon) {
                        current_chain.append(o2);
                    } else if (last.distance_to(o2) <= epsilon) {
                        current_chain.append(o1);
                    } else if (first.distance_to(o1) <= epsilon) {
                        current_chain.insert(0, o2);
                    } else if (first.distance_to(o2) <= epsilon) {
                        current_chain.insert(0, o1);
                    } else {
                        result.append(current_chain);
                        current_chain = PackedVector2Array();
                        current_chain.append(o1);
                        current_chain.append(o2);
                    }
                }
            } else {
                if (current_chain.size() > 0) {
                    result.append(current_chain);
                    current_chain = PackedVector2Array();
                }
            }
        }

        if (current_chain.size() > 0) {
            result.append(current_chain);
        }

        results[idx] = result;
    }

    return results;
}

// --- True batched polygon intersection using Clipper2's native batching ---
Array Clipper2Open::intersect_polygons_batched(
    const Array &polygons,
    const PackedVector2Array &subject_polygon) const
{
    Array results;
    results.resize(polygons.size());

    if (subject_polygon.size() < 3) {
        return results;
    }

    // Convert subject polygon to Clipper2 format
    Clipper2Lib::PathsD subject_paths;
    Clipper2Lib::PathD subject_path;
    for (int i = 0; i < subject_polygon.size(); i++) {
        subject_path.push_back(Clipper2Lib::PointD(
            static_cast<double>(subject_polygon[i].x),
            static_cast<double>(subject_polygon[i].y)
        ));
    }
    subject_paths.push_back(subject_path);

    // Process each polygon individually but using Clipper2's optimized engine
    for (int idx = 0; idx < polygons.size(); idx++) {
        PackedVector2Array clip_polygon = polygons[idx];
        Array result;
        
        if (clip_polygon.size() < 3) {
            results[idx] = result;
            continue;
        }

        // Convert individual clip polygon
        Clipper2Lib::PathsD clip_paths;
        Clipper2Lib::PathD clip_path;
        for (int i = 0; i < clip_polygon.size(); i++) {
            clip_path.push_back(Clipper2Lib::PointD(
                static_cast<double>(clip_polygon[i].x),
                static_cast<double>(clip_polygon[i].y)
            ));
        }
        clip_paths.push_back(clip_path);

        // Use Clipper2's native Intersect function with double precision
        Clipper2Lib::PathsD individual_solution = Clipper2Lib::Intersect(subject_paths, clip_paths, Clipper2Lib::FillRule::NonZero, 2);

        // Convert result back to Godot format
        for (const auto& path : individual_solution) {
            PackedVector2Array result_polygon;
            for (const auto& point : path) {
                result_polygon.append(Vector2(
                    static_cast<float>(point.x),
                    static_cast<float>(point.y)
                ));
            }
            if (result_polygon.size() >= 3) {
                result.append(result_polygon);
            }
        }

        results[idx] = result;
    }

    return results;
}

// Helper: convert Godot polyline (open) to Clipper2 PathD with IsOpen flag
static Clipper2Lib::PathD to_pathd_open(const PackedVector2Array &polyline) {
    Clipper2Lib::PathD path;
    path.reserve(polyline.size());
    for (int i = 0; i < polyline.size(); i++) {
        path.push_back(Clipper2Lib::PointD(
            static_cast<double>(polyline[i].x),
            static_cast<double>(polyline[i].y)
        ));
    }
    return path;
}

// Open subject builder that also adds the last->first segment if input is not closed
static Clipper2Lib::PathD to_pathd_ring_open(const PackedVector2Array &polyline) {
    Clipper2Lib::PathD path;
    int n = polyline.size();
    if (n <= 0) return path;
    path.reserve(n + 1);
    for (int i = 0; i < n; i++) {
        path.push_back(Clipper2Lib::PointD(
            static_cast<double>(polyline[i].x),
            static_cast<double>(polyline[i].y)
        ));
    }
    if (!(polyline[0] == polyline[n - 1])) {
        path.push_back(Clipper2Lib::PointD(
            static_cast<double>(polyline[0].x),
            static_cast<double>(polyline[0].y)
        ));
    }
    return path;
}

static Clipper2Lib::PathD to_pathd_closed(const PackedVector2Array &polygon) {
    Clipper2Lib::PathD path;
    path.reserve(polygon.size());
    for (int i = 0; i < polygon.size(); i++) {
        path.push_back(Clipper2Lib::PointD(
            static_cast<double>(polygon[i].x),
            static_cast<double>(polygon[i].y)
        ));
    }
    return path;
}

// Extract open path solution polylines from Clipper2 open solution
static Array open_solution_to_godot_flat(const Clipper2Lib::PathsD &solution) {
    Array out;
    for (const auto &path : solution) {
        if (path.size() < 2) continue;
        PackedVector2Array line;
        for (const auto &pt : path) {
            line.append(Vector2(
                static_cast<float>(pt.x),
                static_cast<float>(pt.y)
            ));
        }
        out.append(line);
    }
    return out;
}

// Intersect MANY open polylines with MANY closed polygons in one run
Array Clipper2Open::intersect_many_polylines_with_polygons(
    const Array &polylines,
    const Array &polygons) const
{
    Array grouped_results;
    grouped_results.resize(polygons.size());

    // Pre-convert open subjects once
    Clipper2Lib::PathsD open_subjects;
    for (int i = 0; i < polylines.size(); i++) {
        PackedVector2Array line = polylines[i];
        if (line.size() < 2) continue;
        open_subjects.push_back(to_pathd_open(line));
    }
    if (open_subjects.empty()) {
        return grouped_results;
    }

    for (int p = 0; p < polygons.size(); p++) {
        PackedVector2Array poly = polygons[p];
        Array result;
        if (poly.size() < 3) {
            grouped_results[p] = result;
            continue;
        }
        Clipper2Lib::ClipperD c;
        c.AddOpenSubject(open_subjects);
        Clipper2Lib::PathsD closed_clip;
        closed_clip.push_back(to_pathd_closed(poly));
        c.AddClip(closed_clip);
        Clipper2Lib::PathsD closed_solution; // unused closed output
        Clipper2Lib::PathsD open_solution;
        c.Execute(Clipper2Lib::ClipType::Intersection, Clipper2Lib::FillRule::NonZero, closed_solution, open_solution);
        grouped_results[p] = open_solution_to_godot_flat(open_solution);
    }

    return grouped_results;
}

// Difference (outside) of MANY open polylines with MANY closed polygons in one run
Array Clipper2Open::difference_many_polylines_with_polygons(
    const Array &polylines,
    const Array &polygons) const
{
    // Difference against union of all polygons; return flat list
    Clipper2Lib::PathsD open_subjects;
    for (int i = 0; i < polylines.size(); i++) {
        PackedVector2Array line = polylines[i];
        if (line.size() < 2) continue;
        open_subjects.push_back(to_pathd_open(line));
    }
    if (open_subjects.empty()) {
        return Array();
    }
    Clipper2Lib::PathsD closed_union;
    for (int i = 0; i < polygons.size(); i++) {
        PackedVector2Array poly = polygons[i];
        if (poly.size() < 3) continue;
        closed_union.push_back(to_pathd_closed(poly));
    }
    Clipper2Lib::ClipperD c;
    c.AddOpenSubject(open_subjects);
    if (!closed_union.empty()) {
        c.AddClip(closed_union);
    }
    Clipper2Lib::PathsD closed_solution; // unused closed output
    Clipper2Lib::PathsD open_solution;
    c.Execute(Clipper2Lib::ClipType::Difference, Clipper2Lib::FillRule::NonZero, closed_solution, open_solution);
    return open_solution_to_godot_flat(open_solution);
}

// Intersect MANY ring-polylines (adds last->first) with MANY polygons
Array Clipper2Open::intersect_many_ringpolylines_with_polygons(
    const Array &polylines,
    const Array &polygons) const
{
    Array grouped_results;
    grouped_results.resize(polygons.size());

    Clipper2Lib::PathsD open_subjects;
    for (int i = 0; i < polylines.size(); i++) {
        PackedVector2Array line = polylines[i];
        if (line.size() < 2) continue;
        open_subjects.push_back(to_pathd_ring_open(line));
    }
    if (open_subjects.empty()) {
        return grouped_results;
    }

    for (int p = 0; p < polygons.size(); p++) {
        PackedVector2Array poly = polygons[p];
        Array result;
        if (poly.size() < 3) {
            grouped_results[p] = result;
            continue;
        }
        Clipper2Lib::ClipperD c;
        c.AddOpenSubject(open_subjects);
        Clipper2Lib::PathsD closed_clip;
        closed_clip.push_back(to_pathd_closed(poly));
        c.AddClip(closed_clip);
        Clipper2Lib::PathsD closed_solution;
        Clipper2Lib::PathsD open_solution;
        c.Execute(Clipper2Lib::ClipType::Intersection, Clipper2Lib::FillRule::NonZero, closed_solution, open_solution);
        grouped_results[p] = open_solution_to_godot_flat(open_solution);
    }

    return grouped_results;
}
