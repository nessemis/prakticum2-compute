using OpenTK;
using OpenTK.Graphics;
using OpenTK.Graphics.OpenGL;
using OpenTK.Input;
using System;

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

        //angles.x is the angle of rotation around the z axis, angles.y is the rotation around the xy plane.
        Vector3 sphericalCoords;

        Vector3 dBotLeft;
        Vector3 dRight;
        Vector3 dUp;

        Vector3 direction
        {
            get
            {
                Vector3 directionVector = new Vector3((float)Math.Cos(sphericalCoords.X), (float)Math.Sin(sphericalCoords.X), (float)Math.Sin(sphericalCoords.Y));
                directionVector.Normalize();
                return directionVector;
            }
        }

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
            sphericalCoords = Vector3.Zero;
            InitDirections();
        }

        private void InitDirections()
        {
            dRight = new Vector3((float)-Math.Sin(sphericalCoords.X), (float)Math.Cos(sphericalCoords.X), 0.0f);
            dUp = -Vector3.Cross(dRight, direction) / 2;
            dRight /= 2;

            dBotLeft = direction - 1/2f * dRight - 1/2f * dUp;
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
            if (keyboard[OpenTK.Input.Key.W])
            {
                location += 1/10f * direction;
            }
            if (keyboard[OpenTK.Input.Key.S])
            {
                location -= 1/10f * direction;
            }
            if (keyboard[OpenTK.Input.Key.A])
            {
                location -= 1/10f * MovementDirectionRight();
            }
            if (keyboard[OpenTK.Input.Key.D])
            {
                location += 1 / 10f * MovementDirectionRight();
            }
            if (keyboard[OpenTK.Input.Key.Q])
            {
                location += new Vector3(0, 0.0f, 0.1f);
            }
            if (keyboard[OpenTK.Input.Key.E])
            {
                location += new Vector3(0, 0.0f, -0.1f);
            }
            if (keyboard[OpenTK.Input.Key.Up])
            {
                sphericalCoords += new Vector3(0, 0.03f, 0);
            }
            if (keyboard[OpenTK.Input.Key.Down])
            {
                sphericalCoords -= new Vector3(0, 0.03f, 0);
            }
            if (keyboard[OpenTK.Input.Key.Left])
            {
                sphericalCoords -= new Vector3(0.03f, 0, 0);
            }
            if (keyboard[OpenTK.Input.Key.Right])
            {
                sphericalCoords += new Vector3(0.03f, 0, 0);
            }

            InitDirections();

            UpdateShader();
        }

        private Vector3 MovementDirectionRight()
        {
            Vector3 directionRightVector = new Vector3(direction.Y, direction.X, 0);
            directionRightVector.Normalize();
            return directionRightVector;
        }
    }
}