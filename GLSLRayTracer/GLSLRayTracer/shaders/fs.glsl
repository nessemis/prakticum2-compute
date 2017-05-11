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

const float epsilon = 0.0005f;

//-------------------------------------------------------
//Primitives.
//-------------------------------------------------------

struct light{
	vec3 location;
	vec3 color;
};

struct ray{
	vec3 origin;
	vec3 direction;
	float distance;
	float shadowRay;
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
	//we first have to pick the normal such that the ray origin to the normal posi

	float rayOriginDistanceToPlane = dot(-ray.origin, plane.normal) + plane.distance;
	float distance = rayOriginDistanceToPlane/dot(plane.normal, ray.direction);
					
	normal = -plane.normal;
	return distance;
};

//-------------------------------------------------------
//Scene.
//-------------------------------------------------------

#define NUM_SPHERES 2
const sphere spheres[] = {
	{vec3(4, -1.5, 0), 1.0, vec4(1, 0, 0, 1.0)},
	{vec3(4, 1.5, 0), 1.0, vec4(0, 1, 0, 1.0)}
};

#define NUM_PLANES 3
const plane planes[] = {
	{vec3(0, 0, -1), 1.0, vec4(1, 0, 0, 0.5)},
	{vec3(0, -1, 0), 4.0, vec4(0, 1, 0, 0.0)},
	{vec3(0, 1, 0), 4.0, vec4 (0, 0, 1, 0.0)}
};

#define NUM_LIGHTS 1
const light lights[] = {
	{vec3(0, 0, 50), vec3(10000, 10000, 10000)}
};

void intersectWithSpheres (inout ray ray, out vec4 material, out vec3 normal){
	vec3 tmpNormal;
	for (int i = 0; i < NUM_SPHERES && (ray.distance < 0 || ray.shadowRay < 0 || ray.distance > ray.shadowRay); i++) {
		float sphereDistance = intersectSphere(ray, spheres[i], tmpNormal);
		if (sphereDistance > epsilon && (sphereDistance < ray.distance || ray.distance < 0)){
			ray.distance = sphereDistance;
			normal = tmpNormal;
			material = spheres[i].color;
		};
	};
};

void intersectWithPlanes (inout ray ray, out vec4 material, out vec3 normal){
	vec3 tmpNormal;
	for (int i = 0; i < NUM_PLANES && (ray.distance < 0 || ray.shadowRay < 0 || ray.distance > ray.shadowRay); i++) {
		float planeDistance = intersectPlane(ray, planes[i], tmpNormal);
		if (planeDistance > epsilon && (planeDistance < ray.distance || ray.distance < 0)){
			ray.distance = planeDistance;
			normal = tmpNormal;
			material = planes[i].color;
		};
	};
};

//-------------------------------------------------------
//Scene functions.
//-------------------------------------------------------

float updateIntensity(inout float intensity, float distance){
	return intensity / distance / distance;
};

void intersectWithScene(inout ray ray, out vec3 normal, out vec4 reflectedMaterial)
{
	intersectWithSpheres(ray, reflectedMaterial, normal);
	
	intersectWithPlanes(ray, reflectedMaterial, normal);
};

vec3 launchShadowRays(vec3 origin, vec3 incomingDirection, vec3 surfaceNormal){
	vec3 calculatedColor = vec3(0, 0, 0);
	
	//use these dummies because the additional values are not needed.
	vec3 normalDummy;
	vec4 reflectedMaterialDummy;
	
	for (int i = 0; i < NUM_LIGHTS; i++){
		vec3 originToLight = lights[i].location - origin;
		float distanceToLight = sqrt(dot(originToLight, originToLight));
		originToLight /= distanceToLight;
		
		ray shadowRay = ray(origin, originToLight, -1.0, distanceToLight);
		intersectWithScene(shadowRay, normalDummy, reflectedMaterialDummy);
		
		float angle = dot(originToLight, surfaceNormal);
		if (angle < 0)
			angle = 0;
		if (shadowRay.distance < 0.0 || shadowRay.distance > distanceToLight){
			calculatedColor += lights[i].color * updateIntensity(angle, distanceToLight);
		}
	}
	return calculatedColor * dot(-incomingDirection, surfaceNormal);
};

vec3 intersectWithSceneIterator(ray inputRay)
{
	float intensity = 1.0;
	
	vec3 inputRayColor = vec3(0, 0, 0);
	
	vec3 normal;
	vec4 reflectedMaterial;
	
	vec3 intersectionLocation;
	
	ray currentRay = inputRay;
	
	while(intensity > 0.01)
	{
		intersectWithScene(currentRay, normal, reflectedMaterial);
		
		//if the distance to intersection is too large, pretent it doesn't intersect.
		if(currentRay.distance < 0){
			break;
		}
		
		intersectionLocation = currentRay.origin + currentRay.direction * currentRay.distance;
		
		if(reflectedMaterial.w < 1)
		{
			vec3 shadowColor = launchShadowRays(currentRay.origin + currentRay.direction * currentRay.distance, currentRay.direction, normal);
			inputRayColor += (1 - reflectedMaterial.w) * shadowColor * intensity * vec3(reflectedMaterial.x, reflectedMaterial.y, reflectedMaterial.z);
		};
		
		if(reflectedMaterial.w == 0.0){
			break;
		}
		currentRay = ray(intersectionLocation, currentRay.direction - 2 * dot(currentRay.direction, normal) * normal, -1.0, -1.0);
		updateIntensity(intensity, currentRay.distance);
	}
	
	return inputRayColor;
}

//-------------------------------------------------------
//Main program.
//-------------------------------------------------------

vec4 getRayColor(ray ray)
{
	vec3 color = intersectWithSceneIterator(ray);

	return vec4(color.x, color.y, color.z, 1.0);
};

//when the shader program works, try to remove the vec2 to ivec2 conversion.
void main(){
	vec4 pixelLocation = gl_FragCoord;
	vec2 pixelPosition = vec2(pixelLocation.x / windowSize.x, pixelLocation.y / windowSize.y);

	vec3 direction = normalize(dBotLeft + pixelPosition.x * dRight + pixelPosition.y * dUp);

	outputColor = getRayColor(ray(camLocation, direction, -1.0, -1.0));
};