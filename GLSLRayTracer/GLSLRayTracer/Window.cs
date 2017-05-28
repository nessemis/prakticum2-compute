using System;
using OpenTK;
using OpenTK.Graphics;
using OpenTK.Graphics.OpenGL;
using System.IO;
using OpenTK.Input;
using System.Diagnostics;

//sources:
//https://codeyarns.com/2013/06/07/how-to-get-started-with-opentk-using-c-and-visual-studio/
namespace GLSLRayTracer
{
    class Window : GameWindow
    {
        public const int width = 800;
        public const int height = 600;

        int computeHandle;

        int QuadVBO;

        int vPos;

        int uniform_windowSize;

        Camera cam;

        //We leave the framerate unlocked.
        public Window() : base (width, height, GraphicsMode.Default, "RayTracer")
        {
            WindowBorder = WindowBorder.Fixed;
        }

        protected override void OnLoad(EventArgs e)
        {
            base.OnLoad(e);

            GL.Viewport(0, 0, width, height);

            ReloadShader();

            cam = new Camera(computeHandle);
        }

        private void ReloadShader()
        {
            int fragmentShader;
            int vertexShader;

            computeHandle = GL.CreateProgram();

            LoadShader("../../shaders/vs.glsl", ShaderType.VertexShader, computeHandle, out vertexShader);
            LoadShader("../../shaders/fs.glsl", ShaderType.FragmentShader, computeHandle, out fragmentShader);

            GL.LinkProgram(computeHandle);
            GL.UseProgram(computeHandle);

            vPos = GL.GetAttribLocation(computeHandle, "vPosition");

            BufferQuad();

            InitUniform();
            WriteWindowCoord();

        }

        private void InitUniform()
        {
            uniform_windowSize = GL.GetUniformLocation(computeHandle, "windowSize");
        }

        private void WriteWindowCoord()
        {
            GL.Uniform2(uniform_windowSize, (float) width, (float) height);
        }

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

        protected override void OnUpdateFrame(FrameEventArgs e)
        {
            base.OnUpdateFrame(e);

            cam.Update();

            if (Keyboard[Key.Escape])
                Exit();
            if (Keyboard[Key.F])
            {
                ReloadShader();
            }
        }

        protected override void OnRenderFrame(FrameEventArgs e)
        {
            base.OnRenderFrame(e);

            GL.Clear(ClearBufferMask.ColorBufferBit | ClearBufferMask.DepthBufferBit);

            GL.EnableVertexAttribArray(vPos);

            GL.DrawArrays(PrimitiveType.Triangles, 0, 12);

            SwapBuffers();
        }

        private void updateShaderCame()
        {
        }

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
