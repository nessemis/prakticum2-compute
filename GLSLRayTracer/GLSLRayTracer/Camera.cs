using OpenTK;
using OpenTK.Graphics;
using OpenTK.Graphics.OpenGL;
using OpenTK.Input;
using System;

namespace GLSLRayTracer
{
    class Camera
    {
        //why does this have to be in degrees, we pretty much only use radials.
        float verticalViewingAngleInDegrees = 90;

        float verticalViewingAngle
        {
            get
            {
                return (float) (verticalViewingAngleInDegrees / 180f * Math.PI);
            }
        }

        int computeHandle;

        int uniform_renderDebug;
        int uniform_debugTransformationMatrix;

        //(Simple) matrix which transforms the screen space coordinates such that the camera is positioned at (0, 0, 0) and the direction vector points towards (1, 0, 0).
        Matrix4 debugMatrix;

        int uniform_location;
        int uniform_dBotLeft;
        int uniform_dRight;
        int uniform_dUp;

        //Location of the camera.
        Vector3 location;

        //Angles.x is the angle of rotation around the z axis, angles.y is the rotation relative to the xy plane.
        Vector2 rotation;

        //The vector to the center of the "plane" in front of the camera relative to the camera.
        Vector3 direction
        {
            get
            {
                Vector3 directionVector = new Vector3((float)(Math.Sin(rotation.Y) * Math.Cos(rotation.X)), (float)(Math.Sin(rotation.Y) * Math.Sin(rotation.X)), (float)Math.Cos(rotation.Y));
                return directionVector;
            }
        }

        //Points towards the bottom left corner of the "plane" in front of the camera.
        Vector3 dBotLeft;
        //points towards the right/top of the "plane" in front of the camera relative to the bottom left corner.
        Vector3 dRight;
        Vector3 dUp;

        //Whether the debugview should be rendered.
        bool renderDebug = false;

        //Specifies if the uniform variables inside the shader have to be updated.
        bool shaderInvalid;

        public Camera(int computeHandle)
        {
            this.computeHandle = computeHandle;

            InitCamera();

            InitUniform();

            UpdateShader();
        }

        private void InitCamera()
        {
            location = Vector3.Zero;
            rotation = new Vector2(0, (float)Math.PI / 2);
            InitDirections();
        }

        private void InitDirections()
        {
            //sin(x + 1/2pi) = cos(x).
            dRight = new Vector3((float)-Math.Sin(rotation.X), (float)Math.Cos(rotation.X), 0);
            //dright is perpendicular to direction and dright, which bot have length 1, therefor there is no need to normalize.
            dUp = -Vector3.Cross(dRight, direction);

            dRight *= (float)Math.Tan(verticalViewingAngle / 2) * 2;

            dUp *= (float)Math.Tan(verticalViewingAngle / 2) * 2 * ((float)Window.height / Window.width);

            dBotLeft = direction - 1 / 2f * dRight - 1 / 2f * dUp;
        }

        private void InitUniform()
        {
            uniform_renderDebug = GL.GetUniformLocation(computeHandle, "renderDebug");
            uniform_debugTransformationMatrix = GL.GetUniformLocation(computeHandle, "debugTransformationMatrix");

            uniform_location = GL.GetUniformLocation(computeHandle, "camLocation");
            uniform_dBotLeft = GL.GetUniformLocation(computeHandle, "dBotLeft");
            uniform_dRight = GL.GetUniformLocation(computeHandle, "dRight");
            uniform_dUp = GL.GetUniformLocation(computeHandle, "dUp");
        }

        //Updates the debugmatrix
        private void UpdateDebugMatrix()
        {
            debugMatrix = Matrix4.CreateTranslation(-location);
            debugMatrix *= Matrix4.CreateRotationZ(-rotation.X);
            debugMatrix *= Matrix4.CreateRotationY(-(rotation.Y - (float)Math.PI / 2));
        }

        private void UpdateShader()
        {
            GL.Uniform3(uniform_location, location);
            GL.Uniform3(uniform_dBotLeft, dBotLeft);
            GL.Uniform3(uniform_dRight, dRight);
            GL.Uniform3(uniform_dUp, dUp);

            GL.Uniform1(uniform_renderDebug, renderDebug ? 1 : 0);
            if (renderDebug)
            {
                UpdateDebugMatrix();
                GL.UniformMatrix4(uniform_debugTransformationMatrix, false, ref debugMatrix);
            }
        }

        public void Update()
        {
            HandleInput(Keyboard.GetState());
        }

        private void HandleInput(KeyboardState keyboard)
        {
            if (keyboard[OpenTK.Input.Key.W])
            {
                location += 1/10f * direction;
                shaderInvalid = true;
            }
            if (keyboard[OpenTK.Input.Key.S])
            {
                location -= 1/10f * direction;
                shaderInvalid = true;
            }
            if (keyboard[OpenTK.Input.Key.A])
            {
                location -= 1/10f * dRight.Normalized();
                shaderInvalid = true;
            }
            if (keyboard[OpenTK.Input.Key.D])
            {
                location += 1 / 10f * dRight.Normalized();
                shaderInvalid = true;
            }
            if (keyboard[OpenTK.Input.Key.Q])
            {
                location += new Vector3(0, 0.0f, 0.1f);
                shaderInvalid = true;
            }
            if (keyboard[OpenTK.Input.Key.E])
            {
                location += new Vector3(0, 0.0f, -0.1f);
                shaderInvalid = true;
            }
            if (keyboard[OpenTK.Input.Key.Up])
            {
                rotation += new Vector2(0, 0.03f);
                shaderInvalid = true;
            }
            if (keyboard[OpenTK.Input.Key.Down])
            {
                rotation -= new Vector2(0, 0.03f);
                shaderInvalid = true;
            }
            if (keyboard[OpenTK.Input.Key.Left])
            {
                rotation -= new Vector2(0.03f, 0);
                shaderInvalid = true;
            }
            if (keyboard[OpenTK.Input.Key.Right])
            {
                rotation += new Vector2(0.03f, 0);
                shaderInvalid = true;
            }
            if (keyboard[OpenTK.Input.Key.Number1])
            {
                verticalViewingAngleInDegrees -= 0.5f;
                shaderInvalid = true;
            }
            if (keyboard[OpenTK.Input.Key.Number2])
            {
                verticalViewingAngleInDegrees += 0.5f;
                shaderInvalid = true;
            }

            if (keyboard[OpenTK.Input.Key.Number3])
            {
                renderDebug = false;
                shaderInvalid = true;
            }
            if (keyboard[OpenTK.Input.Key.Number4])
            {
                renderDebug = true;
                shaderInvalid = true;
            }


            if (shaderInvalid)
            {
                InitDirections();

                UpdateShader();

                shaderInvalid = false;
            }
        }
    }
}