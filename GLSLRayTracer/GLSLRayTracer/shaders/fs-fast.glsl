//Fragment Shader
#version 430

out vec4 outputColor;

uniform vec2 windowSize;

uniform bool renderDebug;

//Matrix which transforms to world space coordinates.
uniform mat4 debugTransformationMatrix;

//-------------------------------------------------------
//Camera.
//-------------------------------------------------------

uniform vec3 camLocation;

// Vector to the topLeft corner of the camera.
uniform vec3 dBotLeft;
uniform vec3 dRight;
uniform vec3 dUp;

#define epsilon 0.0005

#define minimumIntensity 0.0001

#define maxDistance 10000000000.0

//-------------------------------------------------------
//Primitives.
//-------------------------------------------------------

struct light{
	vec3 location;
	vec3 color;
};

struct material{
	vec3 color;
	float diffuse;
	float reflectivity;
};

struct ray{
	vec3 origin;
	vec3 direction;
	float intensity;
};

struct sphere{
	vec3 location;
	float radius;
	material material;
};

struct plane{
	vec3 normal;
	float distance;
	material material;
};

//-------------------------------------------------------
//Primitive intersections.
//-------------------------------------------------------

float intersectSphere(const ray ray, const sphere sphere){
	vec3 rayOriginToSphere = sphere.location - ray.origin;
	float adjacent = dot(rayOriginToSphere, ray.direction);
	vec3 oppositeToSphereOrigin = rayOriginToSphere - adjacent * ray.direction;
	float opposite = dot(oppositeToSphereOrigin, oppositeToSphereOrigin);
	if (opposite > sphere.radius * sphere.radius){
		return -1.0;
	};
	adjacent -= sqrt(sphere.radius * sphere.radius - opposite);
	return adjacent;
};

float intersectPlane(const ray ray, const plane plane){
	//we first have to pick the normal such that the ray origin to the normal posi
	float rayOriginDistanceToPlane = dot(-ray.origin, plane.normal) + plane.distance;
	float distance = rayOriginDistanceToPlane/dot(plane.normal, ray.direction);
		
	return distance;
};

//-------------------------------------------------------
//Primitive normal calculations.
//-------------------------------------------------------

vec3 sphereNormal(const sphere sphere, const ray ray, const float distance){
	return (distance * ray.direction - sphere.location + ray.origin)/sphere.radius;
}

vec3 planeNormal(const plane plane, const ray ray){
	if (dot(plane.normal, ray.direction) < 0)
		return plane.normal;
	return -plane.normal;
}

//-------------------------------------------------------
//Scene declarations.
//-------------------------------------------------------

#define NUM_SPHERES 2
const sphere spheres[2] = {
	{vec3(4, -1.5, 0), 1.0, material(vec3(1, 0, 0), 0.0, 1.0)},
	{vec3(4, 1.5, 0), 1.0, material(vec3(0, 1, 0), 0.0, 1.0)}
};

#define NUM_PLANES 3
const plane planes[3] = {
	{vec3(0, 0, -1), 1.0, material(vec3(1, 0, 0), 1.0, 0.0)},
	{vec3(0, -1, 0), 4.0, material(vec3(0, 1, 0), 1.0, 0.0)},
	{vec3(0, 1, 0), 4.0, material(vec3(0, 0, 1), 1.0, 0.0)}
};

#define NUM_LIGHTS 1
const light lights[1] = {
	{vec3(0, 0, 2), vec3(1000, 1000, 1000)}
};

//-------------------------------------------------------
//Scene intersections.
//-------------------------------------------------------

void intersectWithSpheres (const ray ray, inout float distance, inout material material, inout vec3 normal){
	for (int i = 0; i < NUM_SPHERES; i++) {
		float sphereDistance = intersectSphere(ray, spheres[i]);
		if (sphereDistance > epsilon && (sphereDistance < distance)){
			distance = sphereDistance;
			normal = sphereNormal(spheres[i], ray, distance);
			material = spheres[i].material;
		};
	};
};

bool intersectWithSpheresShadow (const ray ray, const float distance){
	for (int i = 0; i < NUM_SPHERES; i++) {
		float sphereDistance = intersectSphere(ray, spheres[i]);
		if (sphereDistance > epsilon && (sphereDistance < distance)){
			return true;
		};
	};
	return false;
};

void intersectWithPlanes (const ray ray, inout float distance, inout material material, inout vec3 normal){
	for (int i = 0; i < NUM_PLANES; i++) {
		float planeDistance = intersectPlane(ray, planes[i]);
		if (planeDistance > epsilon && (planeDistance < distance)){
			distance = planeDistance;
			normal = planeNormal(planes[i], ray);
			material = planes[i].material;
		};
	};
};

bool intersectWithPlanesShadow (const ray ray, const float distance){
	for (int i = 0; i < NUM_PLANES; i++) {
		float planeDistance = intersectPlane(ray, planes[i]);
		if (planeDistance > epsilon && (planeDistance < distance)){
			return true;
		};
	};
	return false;
};

//-------------------------------------------------------
//Utility functions.
//-------------------------------------------------------

void updateIntensity(inout ray ray, const float distance){
	ray.intensity /= distance * distance;
};

//-------------------------------------------------------
//Scene functions.
//-------------------------------------------------------

void intersectWithScene(inout ray ray, inout float distance, inout vec3 normal, inout material reflectedMaterial)
{
	intersectWithSpheres(ray, distance, reflectedMaterial, normal);
		
	intersectWithPlanes(ray, distance, reflectedMaterial, normal);
};

bool intersectWithSceneShadowRay(const ray ray, const float distance)
{
	if(intersectWithSpheresShadow(ray, distance))
		return true;
	return intersectWithPlanesShadow(ray, distance);
}

vec3 launchShadowRays(const vec3 origin, const vec3 surfaceNormal){
	vec3 calculatedColor = vec3(0, 0, 0);
	
	vec3 originToLight;
	float distanceToLight;
	
	
	for (int i = 0; i < NUM_LIGHTS; i++){
		originToLight = lights[i].location - origin;
		
		float angle = dot(originToLight, surfaceNormal);
		
		if (angle > 0)
		{
			distanceToLight = sqrt(dot(originToLight, originToLight));
			originToLight /= distanceToLight;
			
			float angle = dot(originToLight, surfaceNormal);
			
			ray shadowRay = ray(origin, originToLight, 1.0);
					
			if (!intersectWithSceneShadowRay(shadowRay, distanceToLight)){
				updateIntensity(shadowRay, distanceToLight);
				shadowRay.intensity *= angle;
				
				updateIntensity(shadowRay, distanceToLight);
				calculatedColor += lights[i].color * shadowRay.intensity;
			}
		}
	}
	return calculatedColor;
};

vec3 intersectWithSceneIterator(ray primaryRay)
{
	vec3 inputRayColor = vec3(0, 0, 0);
	
	vec3 normal;
	
	material reflectedMaterial;
	
	float distance;
	
	vec3 intersectionLocation;
							
	for(int i = 0; i < 10; i++)
	{	
		distance = maxDistance;
																
		intersectWithScene(primaryRay, distance, normal, reflectedMaterial);
								
		//if the distance to intersection is too large, pretent it doesn't intersect.
		if(distance < maxDistance){
			intersectionLocation = primaryRay.origin + primaryRay.direction * distance;
			
			if(reflectedMaterial.diffuse > epsilon){
				vec3 shadowColor = launchShadowRays(primaryRay.origin + primaryRay.direction * distance, normal);
				inputRayColor += reflectedMaterial.diffuse * shadowColor * primaryRay.intensity * reflectedMaterial.color;
			};
									
			if(reflectedMaterial.reflectivity > epsilon){
				primaryRay = ray(intersectionLocation, primaryRay.direction - 2 * dot(primaryRay.direction, normal) * normal, primaryRay.intensity);
				primaryRay.intensity *= reflectedMaterial.reflectivity;
			} else
			{
				break;
			};
		}
		
	}	
	return inputRayColor;
}

//-------------------------------------------------------
//Debug functions.
//-------------------------------------------------------

void intersectDebugRay(ray primaryRay, vec2 pixelDirection, out bool intersection, out vec3 color){
	vec3 normal;
	material reflectedMaterial;
	float distance;
							
	intersectWithScene(primaryRay, distance, normal, reflectedMaterial);
	
	vec3 screen_space_intersection = vec3(debugTransformationMatrix * vec4((distance * primaryRay.direction), 1.0));
	
	float dot_product = dot(screen_space_intersection, vec3(pixelDirection, 0.0));
	
	if(0 < dot_product && dot_product < length(pixelDirection)){
		vec3 cross_product = cross(screen_space_intersection, vec3(pixelDirection, 0.0));
		if(dot(cross_product, cross_product) < 0.1){
			intersection = true;
			color = vec3(1.0, 1.0, 1.0);
		}	
	}
}

vec3 renderDebugPrimitives(vec2 pixelDirection){
	vec3 color = vec3(0, 0, 0);

	for(int i = 0; i < NUM_SPHERES; i++){
		vec3 location = vec3(debugTransformationMatrix * vec4(spheres[i].location, 1.0));
		
		float distanceToEdge = dot(vec3(pixelDirection, 0) - location, vec3(pixelDirection, 0) - location) - spheres[i].radius;
		
		if (abs(distanceToEdge) < 0.01)
			color = spheres[i].material.color;
	}
	
	return color;
};

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

	if(!renderDebug){
		vec3 direction = normalize(dBotLeft + pixelPosition.x * dRight + pixelPosition.y * dUp);
		outputColor = getRayColor(ray(camLocation, direction, 1.0));
	}
	else{
		bool inRay;
		vec3 color;
		
		vec2 pixelDirection = vec2((pixelPosition.y - 0.2) * 10, (pixelPosition.x - 0.5) * 10);
		
		vec3 direction = normalize(dBotLeft + dRight / 2 + pixelPosition.y / 2);
				
		intersectDebugRay(ray(camLocation, direction, 1.0), pixelDirection, inRay, color);
		
		if(!inRay)
			color = renderDebugPrimitives(pixelDirection), 1.0;
			
		outputColor = vec4(color, 1.0);
	}
};