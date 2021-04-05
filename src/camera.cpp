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

#include "camera.hpp"

namespace ror
{
OrbitCamera *mayaCamera;

#ifdef USE_GLFW
void GLFW_buffer_resize(GLFWwindow *a_window, int a_width, int a_height)
{
	(void) a_window;
	mayaCamera->set_bounds(a_width, a_height);
}

void GLFW_mouse_move(GLFWwindow *a_window, double a_x_pos, double a_y_pos)
{
	(void) a_window;
	mayaCamera->mouse_move((int) a_x_pos, (int) a_y_pos);
}

void GLFW_mouse_button(GLFWwindow *a_window, int a_button, int a_action, int a_flags)
{
	(void) a_window;
	(void) a_flags;
	if (a_button == GLFW_MOUSE_BUTTON_1)
	{
		if (a_action == GLFW_PRESS)
			mayaCamera->left_down();
		else
			mayaCamera->left_up();
	}
	else if (a_button == GLFW_MOUSE_BUTTON_2)
	{
		if (a_action == GLFW_PRESS)
			mayaCamera->middle_down();
		else
			mayaCamera->middle_up();
	}
	else if (a_button == GLFW_MOUSE_BUTTON_3 || a_button == GLFW_MOUSE_BUTTON_5)
	{
		if (a_action == GLFW_PRESS)
			mayaCamera->right_down();
		else
			mayaCamera->right_up();
	}
}

void GLFW_mouse_scroll(GLFWwindow *a_window, double a_x_offset, double a_y_offset)
{
	glfw_camera_zoom_by(-a_y_offset);
}

void glfw_camera_init(GLFWwindow *a_window)
{
	mayaCamera = new OrbitCamera();

	glfwSetFramebufferSizeCallback(a_window, GLFW_buffer_resize);
	glfwSetCursorPosCallback(a_window, GLFW_mouse_move);
	glfwSetMouseButtonCallback(a_window, GLFW_mouse_button);
	glfwSetScrollCallback(a_window, GLFW_mouse_scroll);

	int width, height;

	glfwGetFramebufferSize(a_window, &width, &height);

	mayaCamera->set_bounds(width, height);
}

void glfw_camera_update(Matrix4f &a_view_projection, Matrix4f &a_model, Vector3f &a_camera_position)
{
	int a_width, a_height;

	mayaCamera->get_bounds(a_width, a_height);

	// Could also get rid of all GL dependencies
	// glViewport(0, 0, a_width, a_height);

	a_view_projection = mayaCamera->get_view_projection();
	a_model           = mayaCamera->get_model();

	a_camera_position = mayaCamera->get_from();
}

void glfw_camera_visual_volume(Vector3f a_minimum, Vector3f a_maximum)
{
	mayaCamera->set_visual_volume(a_minimum, a_maximum);
}

void glfw_camera_zoom_by(float a_delta)
{
	mayaCamera->zoom_by(a_delta);
}

#endif

}        // namespace ror
