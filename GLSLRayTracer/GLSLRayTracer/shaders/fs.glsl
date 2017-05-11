//Fragment Shader
#version 330

out vec4 outputColor;

uniform vec2 windowSize;

//-------------------------------------------------------
//Camera.
//-------------------------------------------------------

uniform vec3 camLocation;

// Vector to the topLeft corner of the camera.
uniform vec3 dBotLeft;
uniform vec3 dRight;
uniform vec3 dUp;

const float epsilon = 0.05f;

//-------------------------------------------------------
//Primitives.
//-------------------------------------------------------

struct light{
	vec3 location;
	vec4 color;
};

struct ray{
	vec3 origin;
	vec3 direction;
	float distance;
	vec4 color;
};

struct sphere{
	vec3 location;
	float radius;
	vec4 color;
};

float intersectSphere(ray ray, const sphere sphere, out vec3 normal){
	vec3 rayOriginToSphere = sphere.location - ray.origin;
	float adjacent = dot(rayOriginToSphere, ray.direction);
	vec3 oppositeToSphereOrigin = rayOriginToSphere - adjacent * ray.direction;
	float opposite = dot(oppositeToSphereOrigin, oppositeToSphereOrigin);
	if (opposite > sphere.radius * sphere.radius){
		return -1.0;
	};
	adjacent -= sqrt(sphere.radius * sphere.radius - opposite);
	normal = normalize(adjacent * ray.direction - rayOriginToSphere);
	return adjacent;
};

struct plane{
	vec3 normal;
	float distance;
	vec4 color;
};

float intersectPlane(ray ray, const plane plane, out vec3 normal){
	float rayOriginDistanceToPlane = dot(-ray.origin, plane.normal) + plane.distance;
	float distance = rayOriginDistanceToPlane/dot(plane.normal, ray.direction);
	
	if (distance == 1.0 / 0.0)
		return -1.0;
		
	if (dot(plane.normal, ray.direction) > 0)
		normal = plane.normal;

	else 
		normal = plane.normal;
		
	normal = plane.normal;
	return distance;
};

//-------------------------------------------------------
//Scene.
//-------------------------------------------------------

#define NUM_SPHERES 2
const sphere spheres[] = {
	{vec3(4, 0, 0), 1.0, vec4(1, 0, 0, 1)},
	{vec3(4, 1, 0), 1.0, vec4(0, 1, 0, 1)}
};

#define NUM_PLANES 3
const plane planes[] = {
	{vec3(0, 0, -1), 1.0, vec4(1, 0, 0, 1)},
	{vec3(0, -1, 0), 4.0, vec4(0, 1, 0, 1)},
	{vec3(0, 1, 0), 4.0, vec4 (0, 0, 1, 1)}
};

#define NUM_LIGHTS 1
const light lights[] = {
	{vec3(0, 0, 100), vec4(1, 1, 1, 100)}
};

void intersectWithSpheres (inout ray ray, out vec4 material, out vec3 normal){
	vec3 tmpNormal;
	for (int i = 0; i < NUM_SPHERES; i++) {
		float sphereDistance = intersectSphere(ray, spheres[i], tmpNormal);
		if (sphereDistance > 0 && (sphereDistance < ray.distance || ray.distance < 0)){
			ray.distance = sphereDistance;
			normal = tmpNormal;
			material = planes[i].color;
		};
	};
};

void intersectWithPlanes (inout ray ray, out vec4 material, out vec3 normal){
	vec3 tmpNormal;
	for (int i = 0; i < NUM_PLANES; i++) {
		float planeDistance = intersectPlane(ray, planes[i], tmpNormal);
		if (planeDistance > 0 && (planeDistance < ray.distance || ray.distance < 0)){
			ray.distance = planeDistance;
			normal = tmpNormal;
			material = planes[i].color;
		};
	};
};

void intersectWithScene(inout ray ray){
	vec4 reflectedMaterial;
	vec3 normal;

	intersectWithSpheres(ray, reflectedMaterial, normal);
	
	intersectWithPlanes(ray, reflectedMaterial, normal);
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

	return vec4(1.0 / ray.distance / ray.distance, 1.0 / ray.distance / ray.distance, 1.0 / ray.distance / ray.distance, 1.0);
};

//when the shader program works, try to remove the vec2 to ivec2 conversion.
void main(){
	vec4 pixelLocation = gl_FragCoord;
	vec2 pixelPosition = vec2(pixelLocation.x / windowSize.x, pixelLocation.y / windowSize.y);

	vec3 direction = normalize(dBotLeft + pixelPosition.x * dRight + pixelPosition.y * dUp);

	outputColor = getRayColor(ray(camLocation, direction, -1.0, vec4(0.0, 0.0, 0.0, 0.0)));
};