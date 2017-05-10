//VERTEX SHADER
#version 330
in vec3 vPosition;
in vec3 vNormal;
in vec3 vColor;
out vec4 color;
out vec4 normal;

//Scales the landscape to sizes that fit in screen-space (and color-space).
uniform mat4 S;

//Transforms the position in screen-space.
uniform mat4 M;

void main()
{
 gl_Position = M * S * vec4( vPosition, 1.0 );
 color = vec4(1.0, 1.0, 1.0 , 1.0);
 normal = normalize(vec4(vNormal.x, vNormal.y, vNormal.z, 0) * inverse(S));
}