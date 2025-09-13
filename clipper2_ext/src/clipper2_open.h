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
};

#endif // CLIPPER2_OPEN_H
