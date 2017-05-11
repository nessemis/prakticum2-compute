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
	float rayOriginDistanceToPlane = dot(-ray.origin, plane.normal) + plane.distance;
	float distance = rayOriginDistanceToPlane/dot(plane.normal, ray.direction);
			
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
	{vec3(0, 0, 100), vec3(100, 100, 0)}
};

void intersectWithSpheres (inout ray ray, out vec4 material, out vec3 normal){	
	vec3 tmpNormal;
	for (int i = 0; i < NUM_SPHERES; i++) {
		if(ray.shadowRay > epsilon && ray.distance < ray.shadowRay)
			return;
	
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
		if(ray.shadowRay > epsilon && ray.distance < ray.shadowRay)
			return;
			
		float planeDistance = intersectPlane(ray, planes[i], tmpNormal);
		if (planeDistance > 0 && (planeDistance < ray.distance || ray.distance < 0)){
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

vec3 launchShadowRays(vec3 origin, vec3 incomingDirection){
	vec3 calculatedColor = vec3(0, 0, 0);
	
	//use these dummies because the additional values are not needed.
	vec3 normalDummy;
	vec4 reflectedMaterialDummy;
	
	for (int i = 0; i < NUM_LIGHTS; i++){
	
		vec3 originToLight = lights[i].location - origin;
		float distanceToLight = sqrt(dot(originToLight, originToLight));
		originToLight /= distanceToLight;
	
		float angle = dot(incomingDirection, originToLight);
		if (angle < 0){
			break;
		}
	
		ray shadowRay = ray(origin, originToLight, -1.0, distanceToLight);
		intersectWithScene(shadowRay, normalDummy, reflectedMaterialDummy);
		if (shadowRay.distance == -1.0 || shadowRay.distance < distanceToLight){
			calculatedColor += lights[i].color * updateIntensity(angle, distanceToLight);
		}
	}
	return calculatedColor;
};

vec3 intersectWithSceneIterator(ray inputRay)
{
	float intensity = 1.0;
	
	vec3 inputRayColor = vec3(0, 0, 0);
	
	vec3 normal;
	vec4 reflectedMaterial;
	
	vec3 intersectionLocation;
	
	ray currentRay = inputRay;
	
	while(intensity > 0.1)
	{
		intersectWithScene(currentRay, normal, reflectedMaterial);
		
		//if the distance to intersection is too large, pretent it doesn't intersect.
		if(currentRay.distance == -1){
			break;
		}
		
		intersectionLocation = currentRay.origin + currentRay.direction * currentRay.distance;
		
		if(reflectedMaterial.w < 1)
		{
			vec3 shadowColor = launchShadowRays(currentRay.origin + currentRay.direction * currentRay.distance, currentRay.direction);
			inputRayColor += (1 - reflectedMaterial.w) * shadowColor * intensity;
		};
		
		if(reflectedMaterial.w == 0){
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

	return vec4(color, 1.0);
};

//when the shader program works, try to remove the vec2 to ivec2 conversion.
void main(){
	vec4 pixelLocation = gl_FragCoord;
	vec2 pixelPosition = vec2(pixelLocation.x / windowSize.x, pixelLocation.y / windowSize.y);

	vec3 direction = normalize(dBotLeft + pixelPosition.x * dRight + pixelPosition.y * dUp);

	outputColor = getRayColor(ray(camLocation, direction, -1.0, -1.0));
};