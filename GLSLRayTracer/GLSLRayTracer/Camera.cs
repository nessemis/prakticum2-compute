using OpenTK;
using OpenTK.Graphics;
using OpenTK.Graphics.OpenGL;
using OpenTK.Input;

namespace GLSLRayTracer
{
    class Camera
    {
        int computeHandle;

        int uniform_location;
        int uniform_dBotLeft;
        int uniform_dRight;
        int uniform_dUp;

        Vector3 location;
        Vector3 direction;

        Vector3 dBotLeft;
        Vector3 dRight;
        Vector3 dUp;


        public Camera(int computeHandle)
        {
            this.computeHandle = computeHandle;

            InitCamera();

            InitUniform();

            UpdateShader();
        }

        public void Update()
        {
            Input(Keyboard.GetState());
        }

        private void InitUniform()
        {
            uniform_location = GL.GetUniformLocation(computeHandle, "camLocation");
            uniform_dBotLeft = GL.GetUniformLocation(computeHandle, "dBotLeft");
            uniform_dRight = GL.GetUniformLocation(computeHandle, "dRight");
            uniform_dUp = GL.GetUniformLocation(computeHandle, "dUp");
        }

        private void InitCamera()
        {
            location = Vector3.Zero;
            dBotLeft = new Vector3(1f, -0.5f, -0.5f);
            dRight = new Vector3(0.0f, 1.0f, 0.0f);
            dUp = new Vector3(0.0f, 0.0f, 1.0f);
        }

        private void UpdateShader()
        {
            GL.Uniform3(uniform_location, location);
            GL.Uniform3(uniform_dBotLeft, dBotLeft);
            GL.Uniform3(uniform_dRight, dRight);
            GL.Uniform3(uniform_dUp, dUp);
        }

        public void Input(KeyboardState keyboard)
        {
            if (keyboard[OpenTK.Input.Key.A])
            {
                location += new Vector3(0, -0.1f, 0);
            }
            if (keyboard[OpenTK.Input.Key.W])
            {
                location += new Vector3(0.1f, 0.0f, 0);
            }
            if (keyboard[OpenTK.Input.Key.S])
            {
                location += new Vector3(-0.1f, 0, 0);
            }
            if (keyboard[OpenTK.Input.Key.D])
            {
                location += new Vector3(0, 0.1f, 0);
            }

            UpdateShader();
        }
    }
}