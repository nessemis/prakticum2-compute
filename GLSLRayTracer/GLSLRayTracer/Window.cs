using System;
using OpenTK;
using OpenTK.Graphics;
using OpenTK.Graphics.OpenGL;
using System.IO;
using OpenTK.Input;

//sources:
//https://codeyarns.com/2013/06/07/how-to-get-started-with-opentk-using-c-and-visual-studio/
namespace GLSLRayTracer
{
    class Window : GameWindow
    {
        const int width = 800;
        const int height = 600;

        int renderHandle;
        int computeHandle;


        //We leave the framerate unlocked.
        public Window() : base (width, height, GraphicsMode.Default, "RayTracer")
        {
            WindowBorder = WindowBorder.Fixed;
        }

        protected override void OnLoad(EventArgs e)
        {
            base.OnLoad(e);

            int texHandle = GL.GenTexture();

            computeHandle = GL.CreateProgram();

            int computeShader;

            computeHandle = GL.CreateProgram();

            LoadShader("../../shaders/computeRT.glsl", ShaderType.ComputeShader, computeHandle, out computeShader);

            GL.LinkProgram(computeHandle);

            ErrorCode error1 = GL.GetError();

            int framebuffer = GL.GetAttribLocation(computeShader, "framebuffer");

            ErrorCode error = GL.GetError();

            return;
        }

        private void InitGL()
        {

        }

        protected override void OnUpdateFrame(FrameEventArgs e)
        {
            base.OnUpdateFrame(e);

            if (Keyboard[Key.Escape])
                Exit();
        }

        protected override void OnRenderFrame(FrameEventArgs e)
        {
            base.OnRenderFrame(e);

            GL.Clear(ClearBufferMask.ColorBufferBit | ClearBufferMask.DepthBufferBit);

            Matrix4 modelview = Matrix4.LookAt(Vector3.Zero, Vector3.UnitZ, Vector3.UnitY);
            GL.MatrixMode(MatrixMode.Modelview);
            GL.LoadMatrix(ref modelview);

            GL.Begin(PrimitiveType.Triangles);

            GL.Color3(1.0f, 1.0f, 0.0f); GL.Vertex3(-1.0f, -1.0f, 4.0f);
            GL.Color3(1.0f, 0.0f, 0.0f); GL.Vertex3(1.0f, -1.0f, 4.0f);
            GL.Color3(0.2f, 0.9f, 1.0f); GL.Vertex3(0.0f, 1.0f, 4.0f);

            GL.End();

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
