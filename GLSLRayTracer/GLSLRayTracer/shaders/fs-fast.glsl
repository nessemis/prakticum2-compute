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

#define recursionCap 10

//-------------------------------------------------------
//Primitives.
//-------------------------------------------------------

struct light{
	vec3 location;
	vec3 color;
};

struct material{
	//setting color.x = -1 results in a tiled pattern.
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
//Scene declarations.
//-------------------------------------------------------

#define NUM_SPHERES 3
const sphere spheres[NUM_SPHERES] = {
	{vec3(4, -1.5, 0), 1.0, material(vec3(1, 0, 0), 0.0, 1.0)},
	{vec3(4, 1.5, 0), 1.0, material(vec3(0, 1, 0), 0.0, 1.0)},
	{vec3(6, 0, 0), 1.0, material(vec3(0, 1, 1), 1.0, 0.0)}
};

#define NUM_PLANES 1
const plane planes[NUM_PLANES] = {
	{vec3(0, 0, -1), 1.0, material(vec3(-1, 0, 0), 1.0, 0.0)},
};

#define NUM_LIGHTS 1
const light lights[NUM_LIGHTS] = {
	{vec3(0, 0, 2), vec3(1000, 1000, 1000)}
};


/*
//three diffuse only spheres, very dull....
#define NUM_SPHERES 3
const sphere spheres[NUM_SPHERES] = {
	{ vec3(4, -1.5, 0), 1.0, material(vec3(1, 0, 0), 1.0, 0.0) },
	{ vec3(4, 1.5, 0), 1.0, material(vec3(0, 1, 0), 1.0, 0.0) },
	{ vec3(6, 0, 2), 1.0, material(vec3(0, 1, 1), 1.0, 0.0) }
};

#define NUM_PLANES 0
const plane planes[1] = {
	{ vec3(0, 0, -1), 1.0, material(vec3(-1, 0, 0), 1.0, 0.0) },
};

#define NUM_LIGHTS 1
const light lights[NUM_LIGHTS] = {
	{ vec3(0, 0, 2), vec3(1000, 1000, 1000) }
};
*/

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

void intersectWithPlanes (const ray ray, inout float distance, inout material material, inout vec3 normal){
	for (int i = 0; i < NUM_PLANES; i++) {
		float planeDistance = intersectPlane(ray, planes[i]);
		if (planeDistance > epsilon && (planeDistance < distance)){
			distance = planeDistance;
			normal = planeNormal(planes[i], ray);
			material = planes[i].material;
			if(material.color.x  < 0){
				vec3 pos = ray.origin + ray.direction * distance;
				if( ( int(mod(pos.x , 2)) == 0 && int(mod(pos.y, 2)) ==0 ) || 
				( int(mod(pos.x , 2)) == 1 && int(mod(pos.y, 2)) ==1 )){
					material.color = vec3(1,1,1);
				}
				
			}
		};
	};
};

//-------------------------------------------------------
//Scene shadow ray intersections.
//-------------------------------------------------------

bool intersectWithSpheresShadow (const ray ray, const float distance){
	for (int i = 0; i < NUM_SPHERES; i++) {
		float sphereDistance = intersectSphere(ray, spheres[i]);
		if (sphereDistance > epsilon && (sphereDistance < distance)){
			return true;
		};
	};
	return false;
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

//Intersects a ray with the scene
void intersectWithScene(inout ray ray, inout float distance, inout vec3 normal, inout material reflectedMaterial)
{
	intersectWithSpheres(ray, distance, reflectedMaterial, normal);
		
	intersectWithPlanes(ray, distance, reflectedMaterial, normal);
};

//Intersects a shadow ray with the scene
bool intersectWithSceneShadowRay(const ray ray, const float distance)
{
	if(intersectWithSpheresShadow(ray, distance))
		return true;
	return intersectWithPlanesShadow(ray, distance);
}

//Calculates the shadow rays for any given point. 
vec3 intersectShadowRays(const vec3 origin, const vec3 surfaceNormal){
	vec3 calculatedColor = vec3(0, 0, 0);
	
	vec3 originToLight;
	float distanceToLight;
	
	float angle;

	for (int i = 0; i < NUM_LIGHTS; i++){
		originToLight = lights[i].location - origin;
		
		angle = dot(originToLight, surfaceNormal);
		
		//A dot product is very cheap, therefore it's cheaper to do two dot products than risk calculating a root too much.
		if (angle > 0)
		{
			distanceToLight = sqrt(dot(originToLight, originToLight));
			originToLight /= distanceToLight;
			
			angle = dot(originToLight, surfaceNormal);
			
			ray shadowRay = ray(origin, originToLight, 1.0);
					
			//if no valid inteserction was found, proceed to add the light emitted by the light source to the diffuse color.
			if (!intersectWithSceneShadowRay(shadowRay, distanceToLight)){
				updateIntensity(shadowRay, distanceToLight);
				shadowRay.intensity *= angle;
				
				calculatedColor += lights[i].color * shadowRay.intensity;
			}
		}
	}
	return calculatedColor;
};

//Because glsl doesn't allow recursion, a loop is needed to calculate the color.
vec3 intersectWithSceneIterator(ray primaryRay)
{
	vec3 inputRayColor = vec3(0, 0, 0);
	
	vec3 intersectionNormal;
	
	material intersectedMaterial;
	
	float distance;
	
	vec3 intersectionLocation;
							
	for(int i = 0; i < recursionCap; i++)
	{	
		distance = maxDistance;
																
		intersectWithScene(primaryRay, distance, intersectionNormal, intersectedMaterial);
								
		//if the distance to intersection is too large, pretent it doesn't intersect.
		if(distance < maxDistance){
			intersectionLocation = primaryRay.origin + primaryRay.direction * distance;
			
			if(intersectedMaterial.diffuse > epsilon){
				vec3 shadowColor = intersectShadowRays(primaryRay.origin + primaryRay.direction * distance, intersectionNormal);
				inputRayColor += intersectedMaterial.diffuse * shadowColor * primaryRay.intensity * intersectedMaterial.color;
			};
									
			if(intersectedMaterial.reflectivity > epsilon){
				primaryRay = ray(intersectionLocation, primaryRay.direction - 2 * dot(primaryRay.direction, intersectionNormal) * intersectionNormal, primaryRay.intensity);
				primaryRay.intensity *= intersectedMaterial.reflectivity;
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

//Intersects a pixel in screen space.
bool intersectWithVector(vec2 pixelPosition, vec2 rayOrigin, vec2 screen_space_intersection){
	vec2 rayOriginToPixelPosition = pixelPosition - rayOrigin;
	vec2 rayIntersectDir = screen_space_intersection - rayOrigin;
	
	float dot_product = dot(normalize(rayOriginToPixelPosition), rayIntersectDir);
	if(0 < dot_product && length(rayOriginToPixelPosition) < dot_product){
		float dot_product_2 = dot(rayOriginToPixelPosition, normalize(rayIntersectDir));
		float cross_product = dot(rayOriginToPixelPosition, rayOriginToPixelPosition) - dot_product_2 * dot_product_2;
		if(cross_product < 0.0001)
			return true;
	}
	return false;
}

//Intersects shadow rays with the scene. inShadow = true if the pixelPosition is inside the shadowRay, inShadowHit returns true if both inShadow and the shadow ray hit an object.
//This function requires a dedicated debug function because inserting a handle inside the original function would result in performance loss.
void intersectDebugShadowRay(vec2 pixelPosition, vec3 intersectLocaction, vec3 sufaceNorm, out bool inShadow, out bool inShadowHit){
	vec3 originToLight;
	float distanceToLight;
	
	inShadow = false;
	inShadowHit = false;
	
	for (int i = 0; i < NUM_LIGHTS; i++){
		originToLight = lights[i].location - intersectLocaction;
		
		distanceToLight = sqrt(dot(originToLight, originToLight));

		if(distanceToLight < 100 && intersectWithVector(pixelPosition, vec2(debugTransformationMatrix * vec4(intersectLocaction, 1.0)), vec2(debugTransformationMatrix * vec4(lights[i].location, 1.0))))
		{
			inShadow = true;
			
			float angle = dot(originToLight, sufaceNorm);
		
			if (angle > 0)
			{
				originToLight /= distanceToLight;
							
				ray shadowRay = ray(intersectLocaction, originToLight, 1.0);
										 
				if (intersectWithSceneShadowRay(shadowRay, distanceToLight)){
					inShadowHit = true;
					return;
				}
			}
		}
	}
}

//Intersects ray with the scene.
//This function requires a dedicated debug function because inserting a handle inside the original function would result in performance loss.
void intersectDebugRay(ray primaryRay, vec2 pixelDirection, out bool intersection, out vec3 color){
	vec3 intersectionNormal;
	material reflectedMaterial;
	float distance = maxDistance;
	
	intersection = false;
							
	intersectWithScene(primaryRay, distance, intersectionNormal, reflectedMaterial);
	
	vec2 screenSpaceRayOrigin = vec2(debugTransformationMatrix * vec4(primaryRay.origin, 1.0));
	
	vec2 screenSpaceIntersection = vec2(debugTransformationMatrix * vec4((distance * primaryRay.direction + primaryRay.origin), 1.0));
	
	if(intersectWithVector(pixelDirection, screenSpaceRayOrigin, screenSpaceIntersection)){
		intersection = true;
		color = vec3(1.0, 1.0, 0.0);
	}

	else if(reflectedMaterial.diffuse > 0){
		bool inShadow;
		bool inShadowHit;
		
		intersectDebugShadowRay(pixelDirection, distance * primaryRay.direction + primaryRay.origin, intersectionNormal, inShadow, inShadowHit);
		
		if(inShadow)
		{
			intersection = true;
			color = vec3(0.0, 1.0, 1.0);
			if(inShadowHit)
				color = vec3(0.0, 0.5, 0.5);
		}
	}

	if(!intersection && reflectedMaterial.reflectivity > 0){
		primaryRay = ray(distance * primaryRay.direction + primaryRay.origin, primaryRay.direction - 2 * dot(primaryRay.direction, intersectionNormal) * intersectionNormal, 1.0);
		distance = maxDistance;
		intersectWithScene(primaryRay, distance, intersectionNormal, reflectedMaterial);
		
		screenSpaceRayOrigin = vec2(debugTransformationMatrix * vec4(primaryRay.origin, 1.0));

		screenSpaceIntersection = vec2(debugTransformationMatrix * vec4((distance * primaryRay.direction + primaryRay.origin), 1.0));
		
		if(intersectWithVector(pixelDirection, screenSpaceRayOrigin, screenSpaceIntersection)){
			intersection = true;
			color = vec3(0.5, 0.5, 0.0);
		}

	}
}

//Renders the primitives to the debug.
vec3 renderDebugPrimitives(vec2 pixelDirection){
	vec3 color = vec3(0, 0, 0);

	for(int i = 0; i < NUM_SPHERES; i++){
		vec3 location = vec3(debugTransformationMatrix * vec4(spheres[i].location, 1.0));
		float distanceToEdge = sqrt(dot(vec3(pixelDirection, 0) - location, vec3(pixelDirection, 0) - location)) - spheres[i].radius;
		
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

	return vec4(color, 1.0);
};

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
		
		vec3 direction = normalize(dBotLeft + dRight / 2 + dUp / 2);
				
		intersectDebugRay(ray(camLocation, direction, 1.0), pixelDirection, inRay, color);
		
		if(!inRay)
			color = renderDebugPrimitives(pixelDirection), 1.0;
			
		outputColor = vec4(color, 1.0);
	}
};