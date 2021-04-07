// MetalEd Source Code
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

#include "metal_astro_boy.hpp"

#define cimg_display 0
#include "CImg/CImg.h"
#include "camera.hpp"

#include <cstdio>
#include <fstream>
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

// Loads data at sizeof(uint32_t) aligned address
bool align_load_file(const std::string &a_file_path, char **a_buffer, size_t &a_bytes_read)
{
	std::ifstream file(a_file_path, std::ios::in | std::ios::ate | std::ios::binary);

	if (!file.is_open())
	{
		std::cout << "Error! opening file " << a_file_path.c_str() << std::endl;
		return false;
	}

	auto file_size = file.tellg();
	file.seekg(0, std::ios_base::beg);

	if (file_size <= 0)
	{
		std::cout << "Error! reading file size " << a_file_path.c_str() << std::endl;
		return false;
	}

	uint32_t *aligned_pointer = new uint32_t[static_cast<size_t>(file_size) / sizeof(uint32_t)];

	*a_buffer = reinterpret_cast<char *>(aligned_pointer);

	if (*a_buffer == nullptr)
	{
		std::cout << "Error! Out of memory allocating *a_buffer" << std::endl;
		return false;
	}

	file.read(*a_buffer, file_size);
	file.close();

	a_bytes_read = static_cast<size_t>(file_size);

	return true;
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

		astroboy_bbox.create_from_min_max(ror::Vector3f(astro_boy_bounding_box[0], astro_boy_bounding_box[1], astro_boy_bounding_box[2]),
										  ror::Vector3f(astro_boy_bounding_box[3], astro_boy_bounding_box[4], astro_boy_bounding_box[5]));

		ror::glfw_camera_init(this->m_window);
		ror::glfw_camera_visual_volume(astroboy_bbox.minimum(), astroboy_bbox.maximum());

		Uniforms uniforms;

		uniforms.model           = ror::identity_matrix4f;
		uniforms.view_projection = ror::make_perspective(ror::to_radians(90.0f), (float) win_width / (float) win_height, 0.0f, 1000.0f);

		positions      = [device newBufferWithBytes:astro_boy_positions length:astro_boy_positions_array_count * sizeof(float) options:MTLCPUCacheModeDefaultCache];
		normals        = [device newBufferWithBytes:astro_boy_normals length:astro_boy_normals_array_count * sizeof(float) options:MTLCPUCacheModeDefaultCache];
		texture_coords = [device newBufferWithBytes:astro_boy_uvs length:astro_boy_uvs_array_count * sizeof(float) options:MTLCPUCacheModeDefaultCache];
		weights        = [device newBufferWithBytes:astro_boy_weights length:astro_boy_weights_array_count * sizeof(float) options:MTLCPUCacheModeDefaultCache];
		joint_ids      = [device newBufferWithBytes:astro_boy_joints length:astro_boy_joints_array_count * sizeof(int32_t) options:MTLCPUCacheModeDefaultCache];
		indices        = [device newBufferWithBytes:astro_boy_indices length:astro_boy_indices_array_count * sizeof(uint32_t) options:MTLCPUCacheModeDefaultCache];
		mvp            = [device newBufferWithBytes:&uniforms length:sizeof(Uniforms) options:MTLCPUCacheModeDefaultCache];

		// Shaders

		char * shader_code;
		size_t shader_size;

		align_load_file("./assets/shaders/shaders.metal", &shader_code, shader_size);

		NSString *         shader_data = @(shader_code);

		NSError *          shader_error;
		MTLCompileOptions *compileOptions = [MTLCompileOptions new];
		compileOptions.languageVersion    = MTLLanguageVersion1_1;
		id<MTLLibrary> shader_lib         = [device newLibraryWithSource:shader_data options:compileOptions error:&shader_error];

		if (!shader_lib)
		{
			NSLog(@"Couldn't create MTL Shader library: %@", shader_error);
			glfwTerminate();
			exit(EXIT_FAILURE);
		}

		vert_func = [shader_lib newFunctionWithName:@"vertex_main"];
		frag_func = [shader_lib newFunctionWithName:@"fragment_main"];

		delete [] shader_code;

		render_pipeline_descriptor                                 = [MTLRenderPipelineDescriptor new];
		render_pipeline_descriptor.vertexFunction                  = vert_func;
		render_pipeline_descriptor.fragmentFunction                = frag_func;
		render_pipeline_descriptor.colorAttachments[0].pixelFormat = pixel_format;
		render_pipeline_descriptor.depthAttachmentPixelFormat      = MTLPixelFormatDepth32Float;
		render_pipeline_descriptor.vertexDescriptor                = utl::get_astro_boy_vertex_descriptor();

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
		delete [] data;
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

			[cmd_encoder setViewport:(MTLViewport){0.0, 0.0, static_cast<double>(win_width), static_cast<double>(win_height), 0.0, 1.0}];
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

	uint32_t win_width{1024};
	uint32_t win_height{900};
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
