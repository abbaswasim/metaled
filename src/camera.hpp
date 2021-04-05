// Roar Source Code
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

#include "math/rormatrix4.hpp"
#include "math/rormatrix4_functions.hpp"
#include "math/rorvector4.hpp"

/*  OrbitCamera usage
 *  After Glfw window creation call glfw_camera_init();
 *  and set visual volume to limit the camera to a specific bounding box
 *  by calling glfw_camera_visual_volume(min, max);
 *  use glfw_camera_update() to update the viewport and get updated mvp
 */

#define USE_GLFW

#define GLFW_INCLUDE_NONE
#include <GLFW/glfw3.h>
#define GLFW_EXPOSE_NATIVE_COCOA
#include <GLFW/glfw3native.h>

namespace ror
{
class OrbitCamera;

#ifdef USE_GLFW
void GLFW_buffer_resize(GLFWwindow *window, int a_width, int a_height);
void GLFW_mouse_move(GLFWwindow *a_window, int a_x_pos, int a_y_pos);
void GLFW_mouse_button(GLFWwindow *a_window, int a_button, int a_action, int a_flags);

// Use to initialize camera system
void glfw_camera_init(GLFWwindow *a_window);

// Call once to specify visual volume for the camera
void glfw_camera_visual_volume(Vector3f a_minimum, Vector3f a_maximum);

// call to zoom
void glfw_camera_zoom_by(float a_delta);

// Call inside the render loop to get camera updated and recieve MVP back
void glfw_camera_update(Matrix4f &a_view_projection, Matrix4f &a_model, Vector3f &a_camera_position);
#endif

class OrbitCamera
{
  public:
	FORCE_INLINE OrbitCamera();

	FORCE_INLINE void set_bounds(int &a_width, int &a_height);
	FORCE_INLINE void get_bounds(int &a_width, int &a_height);
	FORCE_INLINE void set_visual_volume(Vector3f a_minimum, Vector3f a_maximum);

	FORCE_INLINE void mouse_move(int a_x_pos, int a_y_pos);

	FORCE_INLINE void left_down();
	FORCE_INLINE void left_up();
	FORCE_INLINE void right_down();
	FORCE_INLINE void right_up();
	FORCE_INLINE void middle_down();
	FORCE_INLINE void middle_up();

	FORCE_INLINE Matrix4f get_model_view_projection();
	FORCE_INLINE Matrix4f get_view_projection();
	FORCE_INLINE Matrix4f get_model();
	FORCE_INLINE Vector3f get_from();
	FORCE_INLINE void     update(int a_x_pos, int a_y_pos);
	FORCE_INLINE void     zoom_by(float a_zoom_delta);

  private:
	class MouseInput
	{
	  public:
		friend class OrbitCamera;

		FORCE_INLINE      MouseInput();
		FORCE_INLINE void delta(int &a_x_coordinate, int &a_y_coordinate, int &a_x_difference, int &a_y_difference);
		FORCE_INLINE void is_moving();
		FORCE_INLINE bool is_left_down() const;
		FORCE_INLINE void set_left_down(bool a_value);
		FORCE_INLINE bool is_right_down() const;
		FORCE_INLINE void set_right_down(bool a_value);
		FORCE_INLINE bool is_middle_down() const;
		FORCE_INLINE void set_middle_down(bool a_value);

	  private:
		bool m_button_left   = false;
		bool m_button_right  = false;
		bool m_button_middle = false;
		bool m_moving        = false;

		int m_old_x = 0;
		int m_old_y = 0;
	};

	FORCE_INLINE void update_left_key_function(int &a_x_delta, int &a_y_delta);
	FORCE_INLINE void update_middle_key_function(int &a_x_delta, int &a_y_delta);
	FORCE_INLINE void update_right_key_function(int &a_x_delta, int &a_y_delta);

	FORCE_INLINE void look_at();

	// Used to store mouse input data
	MouseInput *m_mouse = nullptr;

	// Working set matrices
	Matrix4f m_view;
	Matrix4f m_projection;

	Matrix4f m_model_view_projection;        //<! Model view projection matrix
	Matrix4f m_view_projection;              //<! View projection matrix
	Matrix4f m_model;                        //<! Model matrix
	Matrix4f m_normal;                       //<! Normal matrix // TODO: Create normal matrix for xforming normals from transpose of inverse of model-view (top 3x3) without translations Transpose and Inverse removes non-uniform scale from it

	// Direction vectors
	Vector3f m_to   = Vector3f(0.0f, 0.0f, 0.0f);
	Vector3f m_from = Vector3f(0.0f, 0.0f, -10.0f);
	Vector3f m_up   = Vector3f(0.0f, 1.0f, 0.0f);

	// The Camera will make sure it always see this bounding volume
	Vector3f m_minimum = Vector3f(0.0f, 0.0f, 0.0f);
	Vector3f m_maximum = Vector3f(100.0f, 100.0f, 100.0f);

	// Working set variables
	float32_t m_bounding_sphere_radius = 100.0f;
	float32_t m_camera_depth           = 25.0f;
	float32_t m_zooming_depth          = 0.0f;

	float32_t m_x_rotation    = 0.0f;
	float32_t m_y_rotation    = 0.0f;
	float32_t m_x_translation = 0.0f;
	float32_t m_y_translation = 0.0f;

	float32_t m_fov = 60.0f;

	unsigned int m_width  = 800;
	unsigned int m_height = 600;
};
}        // namespace ror

#include "camera.inl"
