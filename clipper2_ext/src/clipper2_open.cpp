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
