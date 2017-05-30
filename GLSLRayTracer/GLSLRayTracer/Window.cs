using System;
using OpenTK;
using OpenTK.Graphics;
using OpenTK.Graphics.OpenGL;
using System.IO;
using OpenTK.Input;
using System.Drawing;
using System.Drawing.Imaging;

//sources:
//https://codeyarns.com/2013/06/07/how-to-get-started-with-opentk-using-c-and-visual-studio/
namespace GLSLRayTracer
{
    class Window : GameWindow
    {
        const bool FAST_RAY_TRACER = false;

        public const int width = 800;
        public const int height = 600;

        int computeHandle;

        int QuadVBO;
        int vPos;

        //referebces to the uniform variables not related to the camera 
        int uniform_windowSize;
        int uniform_skydome;

        Camera camera;

        //We leave the framerate unlocked.
        public Window() : base (width, height, GraphicsMode.Default, "RayTracer")
        {
            WindowBorder = WindowBorder.Fixed;
        }

        protected override void OnLoad(EventArgs e)
        {
            base.OnLoad(e);

            GL.Viewport(0, 0, width, height);

            InitShader();

            camera = new Camera(computeHandle);
        }

        //Initializes the necesarry shaders.
        private void InitShader()
        {
            int fragmentShader;
            int vertexShader;

            computeHandle = GL.CreateProgram();

            LoadShader("../../shaders/vs.glsl", ShaderType.VertexShader, computeHandle, out vertexShader);
            if (FAST_RAY_TRACER)
                LoadShader("../../shaders/fs-fast.glsl", ShaderType.FragmentShader, computeHandle, out fragmentShader);
            else
                LoadShader("../../shaders/fs.glsl", ShaderType.FragmentShader, computeHandle, out fragmentShader);

            GL.LinkProgram(computeHandle);
            GL.UseProgram(computeHandle);

            vPos = GL.GetAttribLocation(computeHandle, "vPosition");

            BufferQuad();

            InitUniform();

            UpdateUniform();
        }

        //Buffers a quad to the shader which fills the screen.
        private void BufferQuad()
        {
            float[] quad = new float[3 * 6]
            {
                -1f, 1f, 0f,
                1f, 1f, 0f,
                1f, -1f, 0f,
                -1f, 1f, 0f,
                1f, -1f, 0f,
                -1f, -1f, 0f
            };

            QuadVBO = GL.GenBuffer();
            GL.BindBuffer(BufferTarget.ArrayBuffer, QuadVBO);
            GL.BufferData(BufferTarget.ArrayBuffer, 6 * 3 * 4, quad, BufferUsageHint.StaticDraw);
            GL.VertexAttribPointer(vPos, 3, VertexAttribPointerType.Float, false, 12, 0);

        }

        //Initializes the uniform variables inside the shader unrelated to the camera.
        private void InitUniform()
        {
            uniform_skydome = GL.GetUniformLocation(computeHandle, "skydome");

            uniform_windowSize = GL.GetUniformLocation(computeHandle, "windowSize");
        }

        //Updates the uniform variables to match their corresponding values.
        private void UpdateUniform()
        {
            GL.Uniform2(uniform_windowSize, (float)width, (float)height);

            BufferSkydome();
        }

        //Buffers the skydome into the shader.
        private void BufferSkydome()
        {

            int texture = GL.GenTexture();

            GL.BindTexture(TextureTarget.Texture2D, texture);


            GL.TexParameter(TextureTarget.Texture2D, TextureParameterName.TextureMinFilter, (int)TextureMinFilter.Linear);
            GL.TexParameter(TextureTarget.Texture2D, TextureParameterName.TextureMagFilter, (int)TextureMagFilter.Linear);

            //skydome obtained from www.sky-domes.com.
            Bitmap skydome = new Bitmap("../../assets/skydome.jpg");
            BitmapData data = skydome.LockBits(new Rectangle(0, 0, skydome.Width, skydome.Height), ImageLockMode.ReadOnly, System.Drawing.Imaging.PixelFormat.Format32bppArgb);

            GL.TexImage2D(TextureTarget.Texture2D, 0, PixelInternalFormat.Rgba, data.Width, data.Height, 0, OpenTK.Graphics.OpenGL.PixelFormat.Bgra, PixelType.UnsignedByte, data.Scan0);

            skydome.UnlockBits(data);

            skydome.Dispose();

            GL.Uniform1(uniform_skydome, 0);

        }
        
        protected override void OnUpdateFrame(FrameEventArgs e)
        {
            base.OnUpdateFrame(e);

            camera.Update();

            if (Keyboard[Key.Escape])
                Exit();
        }
         
        protected override void OnRenderFrame(FrameEventArgs e)
        {
            base.OnRenderFrame(e);

            GL.Clear(ClearBufferMask.ColorBufferBit | ClearBufferMask.DepthBufferBit);

            GL.EnableVertexAttribArray(vPos);

            GL.DrawArrays(PrimitiveType.Triangles, 0, 12);

            SwapBuffers();
        }

        //Loads shadears from files.
        void LoadShader(String name, ShaderType type, int program, out int ID)
        {
            ID = GL.CreateShader(type);
            using (StreamReader sr = new StreamReader(name))
                GL.ShaderSource(ID, sr.ReadToEnd());
            GL.CompileShader(ID);
            GL.AttachShader(program, ID);
            Console.WriteLine(GL.GetShaderInfoLog(ID));
        }
    }
}
