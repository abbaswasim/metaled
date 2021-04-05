// VulkanEd Source Code
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

#include <cstring>
#include <filesystem>
#define GLFW_INCLUDE_NONE
#include <GLFW/glfw3.h>
#define GLFW_EXPOSE_NATIVE_COCOA
#import <GLFW/glfw3native.h>

#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <QuartzCore/QuartzCore.h>

#include "bounds/rorbounding.hpp"
#include "math/rormatrix4.hpp"
#include "math/rormatrix4_functions.hpp"
#include "math/rorvector3.hpp"
#include "skeletal_animation.hpp"

#include "CImg.h"
#include "camera.hpp"

#include <cstdio>
#include <iostream>

static bool         update_animation = true;
static unsigned int render_cycle     = 1;        // 0=Render everything, 1=Render character only, 2=Render skeleton only
static int          focused_bone     = 0;

void key(GLFWwindow *window, int k, int s, int action, int mods)
{
	(void) s;
	(void) mods;

	switch (k)
	{
		case GLFW_KEY_ESCAPE:
			glfwSetWindowShouldClose(window, GLFW_TRUE);
			break;
		case GLFW_KEY_SPACE:
			if (action == GLFW_PRESS)
				update_animation = !update_animation;
			break;
		case GLFW_KEY_G:
			// if (action == GLFW_PRESS)
			//	client_renderer->reset_frame_time();
			break;
		case GLFW_KEY_W:
			// glfw_camera_zoom_by(3.5f);
			break;
		case GLFW_KEY_S:
			// glfw_camera_zoom_by(-3.5f);
			break;
		case GLFW_KEY_C:
			if (action == GLFW_PRESS)
			{
				render_cycle += 1;
				render_cycle = render_cycle % 3;
			}
			break;
		case GLFW_KEY_R:
			// glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);
			break;
		case GLFW_KEY_F:
			// glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
			break;
		case GLFW_KEY_I:
			if (action == GLFW_PRESS)
			{
				focused_bone++;
			}
			break;
		case GLFW_KEY_O:
			if (action == GLFW_PRESS)
			{
				focused_bone--;

				if (focused_bone < 0)
					focused_bone = 0;
			}
			break;
		default:
			return;
	}
}

void read_texture_from_file(const char *a_file_name, unsigned char **a_data, unsigned int &a_width, unsigned int &a_height, unsigned int &a_bpp)
{
	cimg_library::CImg<unsigned char> src(a_file_name);

	unsigned int width  = static_cast<uint32_t>(src.width());
	unsigned int height = static_cast<uint32_t>(src.height());
	unsigned int bpp    = static_cast<uint32_t>(src.spectrum());

	a_width  = width;
	a_height = height;
	a_bpp    = bpp;

	// Data is not stord like traditional RGBRGBRGBRGB triplets but rater RRRRGGGGBBBB
	// In other words R(0,0)R(1,0)R(0,1)R(1,1)G(0,0)G(1,0)G(0,1)G(1,1)B(0,0)B(1,0)B(0,1)B(1,1)
	src.mirror('y');
	unsigned char *ptr = src.data();

	unsigned int size = width * height;

	unsigned char *mixed = new unsigned char[size * 4];

	for (unsigned int i = 0; i < size; i++)
	{
		for (unsigned int j = 0; j < bpp; j++)
		{
			mixed[(i * 4) + j] = ptr[i + (j * size)];
		}
		mixed[(i * 4) + 3] = 255;
	}

	a_bpp = 4;

	*a_data = mixed;
}

static void error_callback(int error, const char *description)
{
	(void) error;

	fputs(description, stderr);
}

typedef struct
{
	ror::Matrix4f model;
	ror::Matrix4f view_projection;
	ror::Matrix4f joints_matrices[44];

} Uniforms;

class MetalApplication
{
  public:
	void run()
	{
		init();
		loop();
		shutdown();
	}

  private:
	static void resize(GLFWwindow *window, int width, int height)
	{
		if (width == 0 || height == 0)
			return;

		auto *app = static_cast<MetalApplication *>(glfwGetWindowUserPointer(window));
	}

	std::pair<unsigned int, double> get_keyframe_time()
	{
		double new_time = 0.0;

		// if (do_animate)
		new_time = glfwGetTime();

		auto delta = new_time - old_time;

		// Note this is very specific to AstroBoy
		static double accumulate_time  = 0.0;
		static int    current_keyframe = 0;
		const double  pf               = 1.166670 / 36.0;

		accumulate_time += delta;
		// if (do_animate)
		current_keyframe = accumulate_time / pf;

		if (accumulate_time > 1.66670 || (current_keyframe > astro_boy_animation_keyframes_count - 5))        // Last 5 frames don't quite work with the animation loop, so ignored
		{
			accumulate_time  = 0.0;
			current_keyframe = 0;
		}

		this->old_time = new_time;

		return std::make_pair(current_keyframe, delta);
	}

	auto animate()
	{
		std::vector<ror::Matrix4f> astro_boy_joint_matrices;
		astro_boy_joint_matrices.reserve(astro_boy_nodes_count);

		auto [current_keyframe, delta_time] = get_keyframe_time();

		auto astro_boy_matrices = ror::get_world_matrices_for_skinning(astro_boy_tree, astro_boy_nodes_count, current_keyframe, delta_time);

		for (size_t i = 0; i < astro_boy_matrices.size(); ++i)
		{
			if (astro_boy_tree[i].m_type == 1)
				astro_boy_joint_matrices.push_back(astro_boy_matrices[i] * ror::get_ror_matrix4(astro_boy_tree[i].m_inverse));
		}

		return astro_boy_joint_matrices;
	}

	void init()
	{
		if (!glfwInit())
		{
			printf("GLFW Init failed, check if you have a working display set!\n");
			exit(EXIT_FAILURE);
		}

		glfwWindowHint(GLFW_DEPTH_BITS, 16);
		glfwWindowHint(GLFW_SAMPLES, 4);
		glfwWindowHint(GLFW_RESIZABLE, GLFW_TRUE);

		glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);

		uint32_t win_width  = 1024;
		uint32_t win_height = 900;

		this->m_window = glfwCreateWindow(win_width, win_height, "Metal Application", nullptr, nullptr);

		if (!this->m_window)
		{
			glfwTerminate();
			printf("GLFW Windows can't be created\n");
			exit(EXIT_FAILURE);
		}

		id<MTLDevice> device = MTLCreateSystemDefaultDevice();

		if (!device)
			exit(EXIT_FAILURE);

		glfwSetErrorCallback(error_callback);

		glfwSetKeyCallback(this->m_window, key);
		glfwSetWindowSizeCallback(this->m_window, resize);

		// Lets use this as a user pointer in glfw
		glfwSetWindowUserPointer(this->m_window, this);

		// Metal setup
		metal_layer             = [CAMetalLayer layer];
		metal_layer.device      = device;
		metal_layer.pixelFormat = pixel_format;
		// metal_layer.depthStencilPixelFormat = MTLPixelFormatDepth32Float;

		NSWindow *nswin              = glfwGetCocoaWindow(this->m_window);
		nswin.contentView.layer      = metal_layer;
		nswin.contentView.wantsLayer = YES;

		queue = [device newCommandQueue];

		float   astro_boy_positions_mod[(astro_boy_positions_array_count / 3) * 4];
		float   astro_boy_normals_mod[(astro_boy_normals_array_count / 3) * 4];
		float   astro_boy_uvs_mod[(astro_boy_uvs_array_count / 2) * 4];
		float   astro_boy_weights_mod[(astro_boy_weights_array_count / 3) * 4];
		int32_t astro_boy_joints_mod[(astro_boy_joints_array_count / 3) * 4];

		// Metal doesn't like 3D positions, prefers 4D
		for (int i = 0; i < astro_boy_positions_array_count / 3; i++)
		{
			astro_boy_positions_mod[i * 4 + 0] = astro_boy_positions[i * 3 + 0];
			astro_boy_positions_mod[i * 4 + 1] = astro_boy_positions[i * 3 + 1];
			astro_boy_positions_mod[i * 4 + 2] = astro_boy_positions[i * 3 + 2];
			astro_boy_positions_mod[i * 4 + 3] = 1.0f;

			astro_boy_normals_mod[i * 4 + 0] = astro_boy_normals[i * 3 + 0];
			astro_boy_normals_mod[i * 4 + 1] = astro_boy_normals[i * 3 + 1];
			astro_boy_normals_mod[i * 4 + 2] = astro_boy_normals[i * 3 + 2];
			astro_boy_normals_mod[i * 4 + 3] = 1.0f;

			astro_boy_uvs_mod[i * 4 + 0] = astro_boy_uvs[i * 2 + 0];
			astro_boy_uvs_mod[i * 4 + 1] = astro_boy_uvs[i * 2 + 1];
			astro_boy_uvs_mod[i * 4 + 2] = 1.0f;
			astro_boy_uvs_mod[i * 4 + 3] = 1.0f;

			astro_boy_weights_mod[i * 4 + 0] = astro_boy_weights[i * 3 + 0];
			astro_boy_weights_mod[i * 4 + 1] = astro_boy_weights[i * 3 + 1];
			astro_boy_weights_mod[i * 4 + 2] = astro_boy_weights[i * 3 + 2];
			astro_boy_weights_mod[i * 4 + 3] = 1.0f;

			astro_boy_joints_mod[i * 4 + 0] = astro_boy_joints[i * 3 + 0];
			astro_boy_joints_mod[i * 4 + 1] = astro_boy_joints[i * 3 + 1];
			astro_boy_joints_mod[i * 4 + 2] = astro_boy_joints[i * 3 + 2];
			astro_boy_joints_mod[i * 4 + 3] = 1.0f;

			ror::Vector3f point{astro_boy_positions[i * 3 + 0],
								astro_boy_positions[i * 3 + 1],
								astro_boy_positions[i * 3 + 2]};

			astroboy_bbox.add_point(point);
		}

		ror::glfw_camera_init(this->m_window);
		ror::glfw_camera_visual_volume(astroboy_bbox.minimum(), astroboy_bbox.maximum());

		Uniforms uniforms;

		uniforms.model           = ror::identity_matrix4f;
		uniforms.view_projection = ror::make_perspective(ror::to_radians(90.0f), (float) win_width / (float) win_height, 0.0f, 1000.0f);

		positions      = [device newBufferWithBytes:astro_boy_positions_mod length:((astro_boy_positions_array_count / 3) * 4) * sizeof(float) options:MTLCPUCacheModeDefaultCache];
		normals        = [device newBufferWithBytes:astro_boy_normals_mod length:((astro_boy_normals_array_count / 3) * 4) * sizeof(float) options:MTLCPUCacheModeDefaultCache];
		texture_coords = [device newBufferWithBytes:astro_boy_uvs_mod length:((astro_boy_uvs_array_count * sizeof(float) / 2) * 4) options:MTLCPUCacheModeDefaultCache];
		weights        = [device newBufferWithBytes:astro_boy_weights_mod length:((astro_boy_weights_array_count * sizeof(float) / 3) * 4) options:MTLCPUCacheModeDefaultCache];
		joint_ids      = [device newBufferWithBytes:astro_boy_joints_mod length:((astro_boy_joints_array_count * sizeof(int32_t) / 3) * 4) options:MTLCPUCacheModeDefaultCache];
		indices        = [device newBufferWithBytes:astro_boy_indices length:astro_boy_indices_array_count * sizeof(uint32_t) options:MTLCPUCacheModeDefaultCache];
		mvp            = [device newBufferWithBytes:&uniforms length:sizeof(Uniforms) options:MTLCPUCacheModeDefaultCache];

		// Shaders
		NSError *          shader_error;
		MTLCompileOptions *compileOptions = [MTLCompileOptions new];
		compileOptions.languageVersion    = MTLLanguageVersion1_1;
		id<MTLLibrary> shader_lib         = [device newLibraryWithSource:@ "using namespace metal; \n"
																  "struct ColoredVertex \n"
																  "{ \n"
																  "    float4 position [[position]]; \n"
																  "    float3 world_position; \n"
																  "    float3 normal; \n"
																  "    float3 texture_coord; \n"
																  "}; \n"
																  "struct Uniforms \n"
																  "{ \n"
																  "    float4x4 model; \n"
																  "    float4x4 view_projection; \n"
																  "    float4x4 joints_matrices[44]; \n"
																  "}; \n"
																  "// Returns the determinant of a 2x2 matrix. \n"
																  "static inline __attribute__((always_inline)) \n"
																  "float spvDet2x2(float a1, float a2, float b1, float b2) \n"
																  "{ \n"
																  "    return a1 * b2 - b1 * a2; \n"
																  "} \n"
																  "// Returns the determinant of a 3x3 matrix. \n"
																  "static inline __attribute__((always_inline)) \n"
																  "float spvDet3x3(float a1, float a2, float a3, float b1, float b2, float b3, float c1, float c2, float c3) \n"
																  "{ \n"
																  "    return a1 * spvDet2x2(b2, b3, c2, c3) - b1 * spvDet2x2(a2, a3, c2, c3) + c1 * spvDet2x2(a2, a3, b2, b3); \n"
																  "} \n"
																  "// Returns the inverse of a matrix, by using the algorithm of calculating the classical \n"
																  "// adjoint and dividing by the determinant. The contents of the matrix are changed. \n"
																  "static inline __attribute__((always_inline)) \n"
																  "float4x4 spvInverse4x4(float4x4 m) \n"
																  "{ \n"
																  "    float4x4 adj;	// The adjoint matrix (inverse after dividing by determinant) \n"
																  "    // Create the transpose of the cofactors, as the classical adjoint of the matrix. \n"
																  "    adj[0][0] =  spvDet3x3(m[1][1], m[1][2], m[1][3], m[2][1], m[2][2], m[2][3], m[3][1], m[3][2], m[3][3]); \n"
																  "    adj[0][1] = -spvDet3x3(m[0][1], m[0][2], m[0][3], m[2][1], m[2][2], m[2][3], m[3][1], m[3][2], m[3][3]); \n"
																  "    adj[0][2] =  spvDet3x3(m[0][1], m[0][2], m[0][3], m[1][1], m[1][2], m[1][3], m[3][1], m[3][2], m[3][3]); \n"
																  "    adj[0][3] = -spvDet3x3(m[0][1], m[0][2], m[0][3], m[1][1], m[1][2], m[1][3], m[2][1], m[2][2], m[2][3]); \n"
																  "    adj[1][0] = -spvDet3x3(m[1][0], m[1][2], m[1][3], m[2][0], m[2][2], m[2][3], m[3][0], m[3][2], m[3][3]); \n"
																  "    adj[1][1] =  spvDet3x3(m[0][0], m[0][2], m[0][3], m[2][0], m[2][2], m[2][3], m[3][0], m[3][2], m[3][3]); \n"
																  "    adj[1][2] = -spvDet3x3(m[0][0], m[0][2], m[0][3], m[1][0], m[1][2], m[1][3], m[3][0], m[3][2], m[3][3]); \n"
																  "    adj[1][3] =  spvDet3x3(m[0][0], m[0][2], m[0][3], m[1][0], m[1][2], m[1][3], m[2][0], m[2][2], m[2][3]); \n"
																  "    adj[2][0] =  spvDet3x3(m[1][0], m[1][1], m[1][3], m[2][0], m[2][1], m[2][3], m[3][0], m[3][1], m[3][3]); \n"
																  "    adj[2][1] = -spvDet3x3(m[0][0], m[0][1], m[0][3], m[2][0], m[2][1], m[2][3], m[3][0], m[3][1], m[3][3]); \n"
																  "    adj[2][2] =  spvDet3x3(m[0][0], m[0][1], m[0][3], m[1][0], m[1][1], m[1][3], m[3][0], m[3][1], m[3][3]); \n"
																  "    adj[2][3] = -spvDet3x3(m[0][0], m[0][1], m[0][3], m[1][0], m[1][1], m[1][3], m[2][0], m[2][1], m[2][3]); \n"
																  "    adj[3][0] = -spvDet3x3(m[1][0], m[1][1], m[1][2], m[2][0], m[2][1], m[2][2], m[3][0], m[3][1], m[3][2]); \n"
																  "    adj[3][1] =  spvDet3x3(m[0][0], m[0][1], m[0][2], m[2][0], m[2][1], m[2][2], m[3][0], m[3][1], m[3][2]); \n"
																  "    adj[3][2] = -spvDet3x3(m[0][0], m[0][1], m[0][2], m[1][0], m[1][1], m[1][2], m[3][0], m[3][1], m[3][2]); \n"
																  "    adj[3][3] =  spvDet3x3(m[0][0], m[0][1], m[0][2], m[1][0], m[1][1], m[1][2], m[2][0], m[2][1], m[2][2]); \n"
																  "    // Calculate the determinant as a combination of the cofactors of the first row. \n"
																  "    float det = (adj[0][0] * m[0][0]) + (adj[0][1] * m[1][0]) + (adj[0][2] * m[2][0]) + (adj[0][3] * m[3][0]); \n"
																  "    // Divide the classical adjoint matrix by the determinant. \n"
																  "    // If determinant is zero, matrix is not invertable, so leave it unchanged. \n"
																  "    return (det != 0.0f) ? (adj * (1.0f / det)) : m; \n"
																  "} \n"
																  "vertex ColoredVertex vertex_main(constant float4 *position [[buffer(0)]], \n"
																  "                                 constant float3 *normal [[buffer(1)]], \n"
																  "                                 constant float3 *texture_coord [[buffer(2)]], \n"
																  "                                 constant float3 *weight [[buffer(3)]], \n"
																  "                                 constant int3 *joint_id [[buffer(4)]], \n"
																  "                                 constant  Uniforms &uniforms[[buffer(5)]], \n"
																  "                                 uint vid [[vertex_id]]) \n"
																  "{ \n"
																  "    ColoredVertex vert; \n"
																  "    float4x4 mvp = uniforms.view_projection * uniforms.model; \n"
																  "	   float4x4 keyframe_transform = \n"
																  "	   uniforms.joints_matrices[joint_id[vid].x] * weight[vid].x + \n"
																  "	   uniforms.joints_matrices[joint_id[vid].y] * weight[vid].y + \n"
																  "	   uniforms.joints_matrices[joint_id[vid].z] * weight[vid].z; \n"
																  "	   float4x4 model_animated = uniforms.model * keyframe_transform; \n"
																  "	   vert.world_position = float4(model_animated * position[vid]).xyz; \n"
																  "    vert.position = uniforms.view_projection * float4(vert.world_position, 1.0f); \n"
																  "    float4x4 model_inverse = transpose(spvInverse4x4(uniforms.model)); \n"
																  "    vert.normal = float3x3(model_inverse[0].xyz, model_inverse[1].xyz, model_inverse[2].xyz) * normal[vid]; \n"
																  "    vert.texture_coord = texture_coord[vid]; \n"
																  "    return vert; \n"
																  "} \n"
																  "fragment float4 fragment_main(ColoredVertex vert [[stage_in]], \n"
																  "                              texture2d<float> color_texture [[texture(0)]])\n"
																  "{ \n"
																  "    float3 light_position = float3(50.0f, 20.0f, 10.0f); \n"
																  "	   float3 view_position = float3(1.0f, 1.0f, 1.0f); \n"
																  "	   float3 light_color = float3(0.9f, 0.9f, 1.0f);\n"
																  "	   float3 object_color = float3(1.0f, 1.0f, 1.0f);\n"
																  "    // ambient\n"
																  "    float ambient_strength = 0.1f;\n"
																  "    float3 ambient = ambient_strength * light_color;\n"
																  "    // diffuse \n"
																  "    float3 norm = normalize(vert.normal);\n"
																  "    float3 light_dir = normalize(light_position - vert.world_position);\n"
																  "    float diff = max(dot(norm, light_dir), 0.0);\n"
																  "    float3 diffuse = diff * light_color;\n"
																  "    // specular\n"
																  "    float specular_strength = 0.5;\n"
																  "    float3 view_dir = normalize(view_position - vert.world_position);\n"
																  "    float3 reflect_dir = reflect(-light_dir, norm);\n"
																  "    float spec = pow(max(dot(view_dir, reflect_dir), 0.0), 32);\n"
																  "    float3 specular = specular_strength * spec * light_color;  \n"
																  "    float3 result = (ambient + diffuse + specular) * object_color;\n"
																  "    constexpr sampler texture_sampler (mag_filter::linear, min_filter::linear);\n"
																  "    return float4(result, 1.0f) * color_texture.sample(texture_sampler, vert.texture_coord.xy); \n"
																  "}\n"
														 options:compileOptions
														   error:&shader_error];
		if (!shader_lib)
		{
			NSLog(@"Couldn't create MTL Shader library: %@", shader_error);
			glfwTerminate();
			exit(EXIT_FAILURE);
		}

		vert_func = [shader_lib newFunctionWithName:@"vertex_main"];
		frag_func = [shader_lib newFunctionWithName:@"fragment_main"];

		render_pipeline_descriptor                                 = [MTLRenderPipelineDescriptor new];
		render_pipeline_descriptor.vertexFunction                  = vert_func;
		render_pipeline_descriptor.fragmentFunction                = frag_func;
		render_pipeline_descriptor.colorAttachments[0].pixelFormat = pixel_format;
		render_pipeline_descriptor.depthAttachmentPixelFormat      = MTLPixelFormatDepth32Float;

		render_pipeline_state = [device newRenderPipelineStateWithDescriptor:render_pipeline_descriptor error:NULL];

		// Setup depth testing
		depth_descriptor                      = [MTLDepthStencilDescriptor new];
		depth_descriptor.depthCompareFunction = MTLCompareFunctionLessEqual;
		depth_descriptor.depthWriteEnabled    = YES;
		depth_state                           = [device newDepthStencilStateWithDescriptor:depth_descriptor];

		MTLTextureDescriptor *depth_target_descriptor = [MTLTextureDescriptor new];
		depth_target_descriptor.width                 = win_width;
		depth_target_descriptor.height                = win_height;
		depth_target_descriptor.pixelFormat           = MTLPixelFormatDepth32Float;
		depth_target_descriptor.storageMode           = MTLStorageModePrivate;
		depth_target_descriptor.usage                 = MTLTextureUsageRenderTarget;

		depthbuffer = [device newTextureWithDescriptor:depth_target_descriptor];

		// Create texture

		uint32_t  tex_width{}, tex_height{}, tex_bpp{};
		uchar8_t *data{nullptr};

		read_texture_from_file("./assets/astroboy/astro_boy.jpg", &data, tex_width, tex_height, tex_bpp);

		assert(tex_bpp == 4);

		MTLTextureDescriptor *texture_descriptor = [[MTLTextureDescriptor alloc] init];

		// Indicate that each pixel has a blue, green, red, and alpha channel, where each channel is
		// an 8-bit unsigned normalized value (i.e. 0 maps to 0.0 and 255 maps to 1.0)
		texture_descriptor.pixelFormat = MTLPixelFormatRGBA8Unorm;

		// Set the pixel dimensions of the texture
		texture_descriptor.width  = tex_width;
		texture_descriptor.height = tex_height;

		// Create the texture from the device by using the descriptor
		texture = [device newTextureWithDescriptor:texture_descriptor];

		// Copy data
		MTLRegion region = {
			{0, 0, 0},                        // MTLOrigin
			{tex_width, tex_height, 1}        // MTLSize
		};
		NSUInteger bytesPerRow = tex_bpp * tex_width;

		[texture replaceRegion:region mipmapLevel:0 withBytes:data bytesPerRow:bytesPerRow];
	}

	void loop()
	{
		while (!glfwWindowShouldClose(this->m_window))
		{
			glfwPollEvents();

			ror::Matrix4f vp;
			ror::Matrix4f m;
			ror::Vector3f camera_position;

			ror::Matrix4f model_matrix{ror::matrix4_rotation_around_x(ror::to_radians(-90.0f))};
			ror::Matrix4f translation{ror::matrix4_translation(ror::Vector3f{0.0f, 0.0f, -(astroboy_bbox.maximum() - astroboy_bbox.minimum()).z} / 2.0f)};

			ror::glfw_camera_update(vp, m, camera_position);

			m = model_matrix * translation * m;

			auto skinning_matrices = this->animate();

			// std::cout << "Skinning matrices size = " << skinning_matrices.size() << std::endl;

			Uniforms *uniform = reinterpret_cast<Uniforms *>(mvp.contents);

			uniform->model           = m;
			uniform->view_projection = vp;

			memcpy(uniform->joints_matrices[0].m_values, skinning_matrices[0].m_values, 44 * sizeof(float) * 16);

			// for (size_t i = 0; i < skinning_matrices.size(); ++i)
			// {
			//	uniform->joints_matrices[i] = skinning_matrices[i];
			// }

			swapchain   = [metal_layer nextDrawable];
			framebuffer = swapchain.texture;

			render_pass_descriptor                                 = [MTLRenderPassDescriptor renderPassDescriptor];
			render_pass_descriptor.colorAttachments[0].texture     = framebuffer;
			render_pass_descriptor.colorAttachments[0].loadAction  = MTLLoadActionClear;
			render_pass_descriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
			render_pass_descriptor.colorAttachments[0].clearColor  = MTLClearColorMake(0.19, 0.04, 0.14, 1.0);
			render_pass_descriptor.depthAttachment.loadAction      = MTLLoadActionClear;
			render_pass_descriptor.depthAttachment.storeAction     = MTLStoreActionDontCare;
			render_pass_descriptor.depthAttachment.clearDepth      = 1.0;
			render_pass_descriptor.depthAttachment.texture         = depthbuffer;

			cmd_buffer = [queue commandBuffer];

			cmd_encoder = [cmd_buffer renderCommandEncoderWithDescriptor:render_pass_descriptor];

			[cmd_encoder setDepthStencilState:depth_state];
			[cmd_encoder setFrontFacingWinding:MTLWindingCounterClockwise];
			[cmd_encoder setCullMode:MTLCullModeBack];

			[cmd_encoder setRenderPipelineState:render_pipeline_state];
			[cmd_encoder setVertexBuffer:positions offset:0 atIndex:0];
			[cmd_encoder setVertexBuffer:normals offset:0 atIndex:1];
			[cmd_encoder setVertexBuffer:texture_coords offset:0 atIndex:2];
			[cmd_encoder setVertexBuffer:weights offset:0 atIndex:3];
			[cmd_encoder setVertexBuffer:joint_ids offset:0 atIndex:4];
			[cmd_encoder setVertexBuffer:mvp offset:0 atIndex:5];
			[cmd_encoder setFragmentTexture:texture atIndex:0];

			// [cmd_encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:astro_boy_positions_array_count / 3 instanceCount:1];

			[cmd_encoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
									indexCount:astro_boy_indices_array_count
									 indexType:MTLIndexTypeUInt32
								   indexBuffer:indices
							 indexBufferOffset:0];

			[cmd_encoder endEncoding];

			[cmd_buffer presentDrawable:swapchain];
			[cmd_buffer commit];
		}
	}

	void shutdown()
	{
		// delete this->m_context;
		glfwDestroyWindow(this->m_window);

		glfwTerminate();

		std::cout << "bye\n";
	}

	double                   old_time{0.0};
	GLFWwindow *             m_window{nullptr};
	id<CAMetalDrawable>      swapchain{};
	CAMetalLayer *           metal_layer{nullptr};
	MTLPixelFormat           pixel_format{MTLPixelFormatBGRA8Unorm};
	id<MTLTexture>           framebuffer{};
	id<MTLTexture>           depthbuffer{};
	MTLRenderPassDescriptor *render_pass_descriptor{nullptr};

	id<MTLCommandQueue>         queue{};
	id<MTLCommandBuffer>        cmd_buffer{};
	id<MTLRenderCommandEncoder> cmd_encoder{};

	id<MTLBuffer> positions;
	id<MTLBuffer> normals;
	id<MTLBuffer> texture_coords;
	id<MTLBuffer> weights;
	id<MTLBuffer> joint_ids;
	id<MTLBuffer> indices;
	id<MTLBuffer> mvp;

	id<MTLFunction> vert_func{};
	id<MTLFunction> frag_func{};

	MTLRenderPipelineDescriptor *render_pipeline_descriptor{nullptr};
	id<MTLRenderPipelineState>   render_pipeline_state{};

	MTLDepthStencilDescriptor *depth_descriptor{nullptr};
	id<MTLDepthStencilState>   depth_state{};

	id<MTLTexture> texture{};

	ror::BoundingBoxf astroboy_bbox{};
};

int main(int argc, char *argv[])
{
	(void) argc;
	(void) argv;

	MetalApplication app;

	try
	{
		app.run();
	}
	catch (const std::exception &e)
	{
		std::cerr << e.what() << std::endl;
		return EXIT_FAILURE;
	}

	return EXIT_SUCCESS;
}
