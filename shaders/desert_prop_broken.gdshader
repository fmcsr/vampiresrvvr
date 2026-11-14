shader_type spatial;
render_mode cull_disabled;

// Desert prop with a jagged break: everything above a broken edge is cut away (broken pillars and
// barrels). Only for a MultiMesh with custom data, which holds each instance's break; see
// desert_prop.gdshaderinc.

#define BROKEN
#include "res://shaders/desert_prop.gdshaderinc"
