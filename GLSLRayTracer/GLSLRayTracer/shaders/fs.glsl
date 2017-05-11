//Fragment Shader
#version 330

out vec4 outputColor;

uniform vec2 windowSize;

// The camera specification
uniform vec3 camLocation;

// Vector to the topLeft corner of the camera.
uniform vec3 dBotLeft;
uniform vec3 dRight;
uniform vec3 dUp;

const float epsilon = 0.05f;

//-------------------------------------------------------
//Primitives.
//-------------------------------------------------------

struct ray{
	vec3 origin;
	vec3 direction;
	float distance;
};

struct sphere{
	vec3 location;
	float radius;
};

float intersectSphere(ray ray, const sphere sphere){
	vec3 rayOriginToSphere = sphere.location - ray.origin;
	float adjacent = dot(rayOriginToSphere, ray.direction);
	vec3 oppositeToSphereOrigin = rayOriginToSphere - adjacent * ray.direction;
	float opposite = dot(oppositeToSphereOrigin, oppositeToSphereOrigin);
	if (opposite > sphere.radius * sphere.radius){
		return -1.0;
	};
	adjacent -= sqrt(sphere.radius * sphere.radius - opposite);
	return adjacent;
}

//-------------------------------------------------------
//Scene.
//-------------------------------------------------------

#define NUM_SPHERES 2
const sphere spheres[] = {
	{vec3(4, 0, 0), 1.0},
	{vec3(4, 1, 0), 1.0}
};

void intersetWithSpheres (inout ray ray){
	for (int i = 0; i < NUM_SPHERES; i++) {
		float sphereDistance = intersectSphere(ray, spheres[i]);
		if (sphereDistance > 0 && (sphereDistance < ray.distance || ray.distance < 0)){
			ray.distance = sphereDistance;
		};
	};
};


void intersectWithScene(inout ray ray){
	intersetWithSpheres(ray);
};

//-------------------------------------------------------
//Main program.
//-------------------------------------------------------

vec4 getRayColor(ray ray){
	intersectWithScene(ray);

	if (ray.distance < 0)
	{
		return vec4(1.0, 0.0, 0.0, 1.0);
	};

	return vec4(ray.distance / 4, ray.distance / 4, ray.distance / 4, 1.0);
};

//when the shader program works, try to remove the vec2 to ivec2 conversion.
void main(){
	vec4 pixelLocation = gl_FragCoord;
	vec2 pixelPosition = vec2(pixelLocation.x / windowSize.x, pixelLocation.y / windowSize.y);

	vec3 direction = normalize(dBotLeft + pixelPosition.x * dRight + pixelPosition.y * dUp);

	outputColor = getRayColor(ray(camLocation, direction, -1.0));
};