#ifndef CLIPPER2_OPEN_H
#define CLIPPER2_OPEN_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/array.hpp>

using namespace godot;

class Clipper2Open : public RefCounted {
    GDCLASS(Clipper2Open, RefCounted);

protected:
    static void _bind_methods();

public:
    // Single version (already exists)
    Array intersect_polyline_with_polygon_deterministic(
        const PackedVector2Array &polyline,
        const PackedVector2Array &polygon,
        double epsilon = 0.0) const;

    // New batched version
    Array intersect_many_polyline_with_polygon_deterministic(
        const Array &polylines,
        const PackedVector2Array &polygon,
        double epsilon = 0.0) const;

    // True batched polygon intersection using Clipper2's native batching
    Array intersect_polygons_batched(
        const Array &polygons,
        const PackedVector2Array &subject_polygon) const;

    Array union_overlap(
        const PackedVector2Array &shared_border,
        const PackedVector2Array &polygon) const;

    // Batched: intersect MANY open polylines with MANY closed polygons (single Clipper2 run)
    // Returns grouped Array: one Array per polygon containing inside segments (PackedVector2Array)
    Array intersect_many_polylines_with_polygons(
        const Array &polylines,
        const Array &polygons) const;

    // Batched: same but treat each input polyline as a closed ring (adds last->first internally)
    Array intersect_many_ringpolylines_with_polygons(
        const Array &polylines,
        const Array &polygons) const;

    // Batched: difference (outside) of MANY open polylines against MANY closed polygons (single Clipper2 run)
    // Returns a flat Array of polylines (PackedVector2Array) representing outside segments
    Array difference_many_polylines_with_polygons(
        const Array &polylines,
        const Array &polygons) const;
};

#endif // CLIPPER2_OPEN_H
