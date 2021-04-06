// Copyright 2018
#pragma once

#include "assets/astroboy/astro_boy_geometry.hpp"
#include "roar.hpp"
#include <Metal/Metal.h>
#include <array>
#include <foundation/rortypes.hpp>

/*
const unsigned int astro_boy_vertex_count = 3616;
const unsigned int astro_boy_positions_array_count = astro_boy_vertex_count * 3;
float32_t astro_boy_positions[astro_boy_positions_array_count];
const unsigned int astro_boy_normals_array_count = astro_boy_vertex_count * 3;
float32_t astro_boy_normals[astro_boy_normals_array_count];
const unsigned int astro_boy_uvs_array_count = astro_boy_vertex_count * 2;
float32_t astro_boy_uvs[astro_boy_uvs_array_count];
const unsigned int astro_boy_weights_array_count = astro_boy_vertex_count * 3;
float32_t astro_boy_weights[astro_boy_weights_array_count];
const unsigned int astro_boy_joints_array_count = astro_boy_vertex_count * 3;
int astro_boy_joints[astro_boy_joints_array_count];
const unsigned int astro_boy_triangles_count = 4881;
const unsigned int astro_boy_indices_array_count = 14643;
unsigned int astro_boy_indices[astro_boy_indices_array_count];
*/

namespace utl
{
static auto get_astro_boy_vertex_descriptor()
{
	uint32_t position_loc_bind = 0;
	uint32_t normal_loc_bind   = 1;
	uint32_t uv_loc_bind       = 2;
	uint32_t weight_loc_bind   = 3;
	uint32_t jointid_loc_bind  = 4;

	MTLVertexDescriptor *vertex_descriptor = [MTLVertexDescriptor vertexDescriptor];

	vertex_descriptor.attributes[position_loc_bind].format      = MTLVertexFormatFloat3;
	vertex_descriptor.attributes[position_loc_bind].bufferIndex = position_loc_bind;
	vertex_descriptor.attributes[position_loc_bind].offset      = 0;

	vertex_descriptor.attributes[normal_loc_bind].format      = MTLVertexFormatFloat3;
	vertex_descriptor.attributes[normal_loc_bind].bufferIndex = normal_loc_bind;
	vertex_descriptor.attributes[normal_loc_bind].offset      = 0;

	vertex_descriptor.attributes[uv_loc_bind].format      = MTLVertexFormatFloat2;
	vertex_descriptor.attributes[uv_loc_bind].bufferIndex = uv_loc_bind;
	vertex_descriptor.attributes[uv_loc_bind].offset      = 0;

	vertex_descriptor.attributes[weight_loc_bind].format      = MTLVertexFormatFloat3;
	vertex_descriptor.attributes[weight_loc_bind].bufferIndex = weight_loc_bind;
	vertex_descriptor.attributes[weight_loc_bind].offset      = 0;

	vertex_descriptor.attributes[jointid_loc_bind].format      = MTLVertexFormatInt3;
	vertex_descriptor.attributes[jointid_loc_bind].bufferIndex = jointid_loc_bind;
	vertex_descriptor.attributes[jointid_loc_bind].offset      = 0;

	vertex_descriptor.layouts[position_loc_bind].stride       = sizeof(float32_t) * 3;
	vertex_descriptor.layouts[position_loc_bind].stepFunction = MTLVertexStepFunctionPerVertex;

	vertex_descriptor.layouts[normal_loc_bind].stride       = sizeof(float32_t) * 3;
	vertex_descriptor.layouts[normal_loc_bind].stepFunction = MTLVertexStepFunctionPerVertex;

	vertex_descriptor.layouts[uv_loc_bind].stride       = sizeof(float32_t) * 2;
	vertex_descriptor.layouts[uv_loc_bind].stepFunction = MTLVertexStepFunctionPerVertex;

	vertex_descriptor.layouts[weight_loc_bind].stride       = sizeof(float32_t) * 3;
	vertex_descriptor.layouts[weight_loc_bind].stepFunction = MTLVertexStepFunctionPerVertex;

	vertex_descriptor.layouts[jointid_loc_bind].stride       = sizeof(int32_t) * 3;
	vertex_descriptor.layouts[jointid_loc_bind].stepFunction = MTLVertexStepFunctionPerVertex;

	return vertex_descriptor;
}

}        // namespace utl
