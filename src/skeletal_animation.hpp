// Wasim Abbas
// http://www.waZim.com
// Copyright (c) 2021
//
// Permission is hereby granted, free of charge, to any person obtaining
// a copy of this software and associated documentation files (the 'Software'),
// to deal in the Software without restriction, including without limitation
// the rights to use, copy, modify, merge, publish, distribute, sublicense,
// and/or sell copies of the Software, and to permit persons to whom the Software
// is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
// IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
// CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
// TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
// OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
// Version: 1.0.0

#pragma once

#include "assets/astroboy/astro_boy_geometry.hpp"
#include "assets/astroboy/astro_boy_animation.hpp"
#include "math/rormatrix4.hpp"
#include "math/rorvector3.hpp"
#include <cassert>
#include <cstddef>
#include <iostream>
#include <map>

namespace ror
{
ror::Matrix4f get_ror_matrix4(ColladaMatrix &mat)
{
	ror::Matrix4f matrix;

	for (int i = 0; i < 16; ++i)
		matrix.m_values[i] = mat.v[i];

	// Since collada matrices are colum_major BUT they are provided in row-major for readibility, you need to transpose when you read
	// https://www.khronos.org/files/collada_spec_1_4.pdf 5-77 "Matrices in COLLADA are column matrices in the mathematical sense. These matrices are written in row- major order to aid the human reader. See the example."
	return matrix.transposed();
}

ror::Matrix4f get_animated_transform(AstroBoyTreePtr a_node, unsigned int a_index, unsigned int a_current_keyframe, double a_delta_time)
{
	if (astro_boy_animation_keyframe_matrices.find(a_index) != astro_boy_animation_keyframe_matrices.end())
	{
		assert(a_current_keyframe + 1 < astro_boy_animation_keyframes_count);

		float a = astro_boy_animation_keyframe_times[a_current_keyframe];
		float b = astro_boy_animation_keyframe_times[a_current_keyframe + 1];
		float t = a_delta_time / (b - a);

		return ror::matrix4_interpolate(get_ror_matrix4(astro_boy_animation_keyframe_matrices[a_index][a_current_keyframe]),
										get_ror_matrix4(astro_boy_animation_keyframe_matrices[a_index][a_current_keyframe + 1]), t);
	}
	else
	{
		return get_ror_matrix4(a_node[a_index].m_transform);
	}

	return ror::Matrix4f();
}

// Recursive function to get valid parent matrix, This is very unoptimised
// These matrices are calculated for each node, It should be cached instead, and have an iterative solution to it
ror::Matrix4f get_world_matrix(AstroBoyTreePtr a_node, unsigned int a_index)
{
	if (a_node[a_index].m_parent_id == -1)
		return get_ror_matrix4(a_node[a_index].m_transform);
	else
		return get_world_matrix(a_node, a_node[a_index].m_parent_id) * get_ror_matrix4(a_node[a_index].m_transform);
}

// Recursive function to get valid parent matrix, This is very unoptimised
// These matrices are calculated for each node, It should be cached instead, and have an iterative solution to it
ror::Matrix4f get_world_matrix_animated(AstroBoyTreePtr a_node, unsigned int a_index, unsigned int a_current_keyframe, double a_delta_time)
{
	if (a_node[a_index].m_parent_id == -1)
		return get_animated_transform(a_node, a_index, a_current_keyframe, a_delta_time);
	else
		return get_world_matrix_animated(a_node, a_node[a_index].m_parent_id, a_current_keyframe, a_delta_time) * get_animated_transform(a_node, a_index, a_current_keyframe, a_delta_time);
}

std::vector<ror::Matrix4f> get_world_matrices_for_skinning(AstroBoyTreePtr root, unsigned int joint_count, unsigned int a_current_keyframe, double a_delta_time)
{
	std::vector<ror::Matrix4f> world_matrices;
	world_matrices.reserve(joint_count);

	for (unsigned int i = 0; i < joint_count; ++i)
	{
		auto matrix = get_world_matrix_animated(root, i, a_current_keyframe, a_delta_time);
		matrix      = matrix * get_ror_matrix4(astro_boy_skeleton_bind_shape_matrix);        // at the moment bind_shape is identity
		world_matrices.push_back(matrix);
	}

	return world_matrices;
}

}
