//Fragment Shader
#version 430

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

const float epsilon = 0.0005;

const float minimumIntensity = 0.0001;

const float maxDistance = 10000000000.0;

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
	
	//refractive index;
	float r_index;
};

struct ray{
	vec3 origin;
	vec3 direction;
	float intensity;
	float shadowRay;
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

struct triangle{
	vec3 v1;
	
	//edges from v1 to vertex ei.
	vec3 e2;
	vec3 e3;
	
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

//möller-trumbore ray-triangle intersection algoritm.
float intersectTriangle(const ray ray, const triangle triangle){
	vec3 p, q, t;
	float det, inv_det, u, v;
	float distance;

	p = cross(ray.direction, triangle.e3);
	det = dot(triangle.e2, p);
	if(abs(det) < epsilon) return -1;
	inv_det = 1/det;
	t = ray.origin - triangle.v1;
	u = dot(t, p) * inv_det;
	if(u < 0 || u > 1) return -1;
	q = cross(t, triangle.e2);
	v = dot(ray.direction, q) * inv_det;
	if(v < 0 || u + v  > 1) return -1;
	distance = dot(triangle.e3, q) * inv_det;
	if(distance > epsilon) 
	{
		return distance;
	};
	return -1;
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

vec3 triangleNormal(const triangle triangle, const ray ray){
	vec3 normal = cross(triangle.e2, triangle.e3);
	if (dot(normal, ray.direction) < 0)
		return normal;
	 return -normal;
}

//-------------------------------------------------------
//Scene declarations.
//-------------------------------------------------------

#define NUM_SPHERES 2
const sphere spheres[2] = {
	{vec3(4, -1.5, 0), 1.0, material(vec3(1, 0, 0), 0.0, 1.0, 1.0)},
	{vec3(4, 1.5, 0), 1.0, material(vec3(0, 1, 0), 0.0, 1.0, 1.0)}
};

#define NUM_PLANES 3
const plane planes[3] = {
	{vec3(0, 0, -1), 1.0, material(vec3(1, 0, 0), 1.0, 0.0, 1.0)},
	{vec3(0, -1, 0), 4.0, material(vec3(0, 1, 0), 1.0, 0.0, 1.0)},
	{vec3(0, 1, 0), 4.0, material(vec3(0, 0, 1), 1.0, 0.0, 1.0)}
};

#define NUM_TRIANGLES 0
const triangle triangles[1] = {
	{vec3(2, -1, 0), vec3(0, 2, 0), vec3(0, 1, 1), material(vec3(1, 1, 0), 1.0, 0.0, 0.0)}
};

#define NUM_LIGHTS 1
const light lights[1] = {
	{vec3(0, 0, 50), vec3(10000000, 10000000, 10000000)}
};

//-------------------------------------------------------
//Scene intersections.
//-------------------------------------------------------

void intersectWithSpheres (inout ray ray, inout float distance, inout material material, inout vec3 normal){
	for (int i = 0; i < NUM_SPHERES && (distance < 0 || ray.shadowRay < 0 || distance > ray.shadowRay); i++) {
		float sphereDistance = intersectSphere(ray, spheres[i]);
		if (sphereDistance > epsilon && (sphereDistance < distance || distance < 0)){
			distance = sphereDistance;
			normal = sphereNormal(spheres[i], ray, distance);
			material = spheres[i].material;
		};
	};
};

void intersectWithPlanes (inout ray ray, inout float distance, inout material material, inout vec3 normal){
	for (int i = 0; i < NUM_PLANES && (distance < 0 || ray.shadowRay < 0 || distance > ray.shadowRay); i++) {
		float planeDistance = intersectPlane(ray, planes[i]);
		if (planeDistance > epsilon && (planeDistance < distance || distance < 0)){
			distance = planeDistance;
			normal = planeNormal(planes[i], ray);
			material = planes[i].material;
		};
	};
};

void intersectWithTriangles (inout ray ray, inout float distance, inout material material, inout vec3 normal){
	for (int i = 0; i < NUM_TRIANGLES && (distance < 0 || ray.shadowRay < 0 || distance > ray.shadowRay); i++) {
		float triangleDistance = intersectTriangle(ray, triangles[i]);
		if (triangleDistance > epsilon && (triangleDistance < distance || distance < 0)){
			distance = triangleDistance;
			normal = triangleNormal(triangles[i], ray);
			material = triangles[i].material;
		};
	};
};

//-------------------------------------------------------
//Utility functions.
//-------------------------------------------------------

void updateIntensity(inout ray ray, float distance){
	ray.intensity /= distance * distance;
};

int mostSignificantRay(const ray rayBuffer[32], int bufferLog){
	int index = findLSB(bufferLog);
	if (index == -1)
		return -1;
	bufferLog ^= 1 << index;

	int i;
		
	while(true){
		i = findLSB(bufferLog);
		if (i == -1)
			break;
			
		bufferLog ^= 1 << i;
		if (rayBuffer[index].intensity < rayBuffer[i].intensity)
			index = i;
		
	}
	return index;
}

int leastSignificantRay(const ray rayBuffer[32], int bufferLog){
	int index = findLSB(bufferLog);
	if (index == -1)
		return -1;
		
	bufferLog ^= 1 << index;
	int i;
	
	while(true){
		i = findLSB(bufferLog);
		if (i == -1)
			break;
			
		bufferLog ^= 1 << i;
		if (rayBuffer[index].intensity > rayBuffer[i].intensity)
			index = i;
		
	}
	return index;
}

int optimalLogIndex(const ray rayBuffer[32], const int bufferLog){
	int index = findLSB(bufferLog ^ 0xFFFFFFFF);
	if (index == -1)
		return leastSignificantRay(rayBuffer, bufferLog);
	return index;
};

//-------------------------------------------------------
//Scene functions.
//-------------------------------------------------------

void intersectWithScene(inout ray ray, inout float distance, inout vec3 normal, inout material reflectedMaterial)
{
	intersectWithSpheres(ray, distance, reflectedMaterial, normal);
		
	intersectWithPlanes(ray, distance, reflectedMaterial, normal);
	
	intersectWithTriangles(ray, distance, reflectedMaterial, normal);
};

vec3 launchShadowRays(vec3 origin, vec3 incomingDirection, vec3 surfaceNormal){
	vec3 calculatedColor = vec3(0, 0, 0);
	
	//use these dummies because the additional values are not needed.
	vec3 normalDummy;
	material reflectedMaterialDummy;
	float distance;
	
	for (int i = 0; i < NUM_LIGHTS; i++){
		distance = -1;
	
		vec3 originToLight = lights[i].location - origin;
		float distanceToLight = sqrt(dot(originToLight, originToLight));
		originToLight /= distanceToLight;
		
		ray shadowRay = ray(origin, originToLight, 1.0, distanceToLight);
		intersectWithScene(shadowRay, distance, normalDummy, reflectedMaterialDummy);
		
		float angle = dot(originToLight, surfaceNormal);
		
		if (angle < 0)
			break;
			
		updateIntensity(shadowRay, distanceToLight);
		shadowRay.intensity *= angle;
		
		if (distance < 0.0 || distance > distanceToLight){
			updateIntensity(shadowRay, distanceToLight);
			calculatedColor += lights[i].color * shadowRay.intensity;
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
		
	ray rayBuffer[32];
    rayBuffer[0] = primaryRay;
	
	int index;
		
	int bufferLog = 1;
			
	for(int i = 0; i < 10; i++)
	{	
		distance = -1;
		
		index = mostSignificantRay(rayBuffer, bufferLog);
		if(index == -1)
			break;
		
		bufferLog ^= 1 << index;
														
		intersectWithScene(rayBuffer[index], distance, normal, reflectedMaterial);
								
		//if the distance to intersection is too large, pretent it doesn't intersect.
		if(distance > epsilon){
										
			intersectionLocation = rayBuffer[index].origin + rayBuffer[index].direction * distance;
			
			if(reflectedMaterial.diffuse > epsilon){
				vec3 shadowColor = launchShadowRays(rayBuffer[index].origin + rayBuffer[index].direction * distance, rayBuffer[index].direction, normal);
				inputRayColor += reflectedMaterial.diffuse * shadowColor * rayBuffer[index].intensity * reflectedMaterial.color;
			};
			
			float rc = 1.0;
			
			if(reflectedMaterial.r_index > epsilon){
				//Reflection Coefficient
				rc = reflectedMaterial.r_index + (1 - reflectedMaterial.r_index) * pow((1 - dot(-rayBuffer[index].direction, normal)), 5);
			
				//for performance optimisation, a reflection results into overwriting the current ray.
				if(reflectedMaterial.reflectivity > epsilon){
					rayBuffer[index] = ray(intersectionLocation, rayBuffer[index].direction - 2 * dot(rayBuffer[index].direction, normal) * normal, rayBuffer[index].intensity, -1.0);
					rayBuffer[index].intensity *= reflectedMaterial.reflectivity * rc;
					if (rayBuffer[index].intensity > minimumIntensity)
						bufferLog |= 1 << index;
				}
				
				if (rc  > minimumIntensity)
				{
					int rRayIndex = optimalLogIndex(rayBuffer, bufferLog);
				}
				
				if ((bufferLog & (1 << index)) < 0){
					
				}
			}
			
		}
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

	outputColor = getRayColor(ray(camLocation, direction, 1, -1));
};