//Compute Shader
#version 430

// Shamelessly derived from
//https://github.com/LWJGL/lwjgl3-wiki/wiki/2.6.1.-Ray-tracing-with-OpenGL-Compute-Shaders-(Part-I)

layout(binding = 0, rgba32f) uniform image2D framebuffer;

// The camera specification
uniform vec3 location;

// Vector to the topLeft corner of the camera.
uniform vec3 topLeft;
uniform vec3 dRight;
uniform vec3 dDown;

struct sphere{
	vec3 location;
	float radius;
};

#define NUM_SPHERES 2
const sphere spheres[] = {
	{vec3(2, 0, 0), 1.0},
	{vec3(2, 1, 0), 1.0}
};

float intersectSphere(vec3 rayOrigin, vec3 rayDirection, const sphere sphere){
	vec3 rayOriginToSphere = sphere.location - rayOrigin;
	float adjacent = dot(rayOrigin, rayDirection);
	vec3 oppositeToSphereOrigin = rayOriginToSphere - adjacent * rayDirection;
	float opposite = dot(oppositeToSphereOrigin, oppositeToSphereOrigin);
	if (opposite > sphere.radius * sphere.radius){
		return -1;
	};
	adjacent -= sqrt(sphere.radius * sphere.radius - opposite);
	return adjacent;
}

float intersetWithSpheres (vec3 rayOrigin, vec3 rayDirection){
	float distance = -1;
	
	for (int i = 0; i < NUM_SPHERES; i++) {
		float sphereDistance = intersectSphere(rayOrigin, rayDirection, spheres[i]);
		if (sphereDistance > 0 && (sphereDistance < distance || distance < 0)){
			distance = sphereDistance;
		};
	};
	
	return distance;
};

float intersectWithObjects(vec3 rayOrigin, vec3 rayDirection){
	float distance = -1;
	
	float sphereDistance = intersetWithSpheres(rayOrigin, rayDirection);

	if (sphereDistance > 0 && (sphereDistance < distance || distance < 0)){
		distance = sphereDistance;
	};

	return distance;
};

vec4 intersectWithScene(vec3 rayOrigin, vec3 rayDirection){
	float rayLength = intersectWithObjects(rayOrigin, rayDirection);

	if (rayLength < 0)
	{
		return vec4(1.0, 1.0, 0.0, 1.0);
	};
		
	
	return vec4(rayLength / 100, rayLength / 100, rayLength / 100, 1.0);
};

//when the shader program works, try to remove the vec2 to ivec2 conversion.
void main(void){
	ivec2 pixelPosition = ivec2(gl_GlobalInvocationID.xy);
	ivec2 frameSize = imageSize(framebuffer);
	
	//potentially unnecessary code.
	if(pixelPosition.x >= frameSize.x || pixelPosition.y >= frameSize.y){
		return;
	};
		
	//normalize our pixelPositions to easily  convert rays. Lots seems redundant cleanup later.
	vec2 normPixelPosition = vec2(pixelPosition) / vec2(frameSize.x, frameSize);
	vec3 direction = normalize(topLeft + normPixelPosition.x * dRight + normPixelPosition.y * dDown);
	vec4 color = vec4(0.5, 0.5, 0, 0.5);
	//	vec4 color = intersectWithScene(location, direction);
	imageStore(framebuffer, pixelPosition, color);
};