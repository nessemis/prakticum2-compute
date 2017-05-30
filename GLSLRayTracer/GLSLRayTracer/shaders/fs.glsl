//Fragment Shader
#version 430

out vec4 outputColor;

uniform vec2 windowSize;

uniform bool renderDebug;

uniform sampler2D skydome;

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

#define PI 3.141592654

#define RAYS_PER_PIXEL_VERTICAL 1

#define RAYS_PER_PIXEL_HORIZONTAL 1

//taking a lower number will result in an overflow inducing strange artefacts (very strange ones at that).
#define RAY_BUFFER_SIZE max(RAYS_PER_PIXEL_VERTICAL * RAYS_PER_PIXEL_HORIZONTAL, 10)

//-------------------------------------------------------
//Primitives.
//-------------------------------------------------------

struct ray {
	vec3 origin;
	vec3 direction;
	float intensity;

	//refractive index of the material the ray is currently traveling in.
	float r_index;
};

struct light{
	vec3 location;
	vec3 color;
};

struct spotlight{
    vec3 location;
	vec3 color;
	vec3 direction;

	//In cos(angle).
    float angle;
};

struct material{
	vec3 color;
	float diffuse;
	float specularHardness;
	float reflectivity;

	//amount the refraction matters to the total ray definition.
	float emitance;

	//refractive index;
	float r_index;
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
	int texture;
};

struct triangle{
	vec3 v1;
	//edges from v1 to vertex ei.
	vec3 e2;
	vec3 e3;

	material material;
};

//-------------------------------------------------------
//Scene declarations.
//-------------------------------------------------------

#define NUM_SPHERES 4
const sphere spheres[4] = {
	{ vec3(4, -1.5, 0), 1.0, material(vec3(1, 0, 0), 0.0, 1.0, 0.0, 1.0, 1.0) },
	{ vec3(4, 1.5, 0), 1.0, material(vec3(0, 1, 0), 0.0, 1.0, 0.0, 1.0, 1.5) },
	{ vec3(6, 0, 0), 1.0, material(vec3(1, 1, 0), 1.0, 1.5, 0.0, 0.0, 1.0) },
	{ vec3(15, 0, 3.0), 16.0, material(vec3(1, 1, 1), 0.0, 1.5, 1.0, 0.0, 1.0) }
};

#define NUM_PLANES 1
const plane planes[1] = {
	{ vec3(0, 0, -1), 1.0, material(vec3(1, 0, 1), 1.0, 1.0, 0.3, 0.0, 1.0), 1 }
};

#define NUM_TRIANGLES 0
const triangle triangles[1] = {
	{ vec3(2, -1, 0), vec3(0, 2, 0), vec3(0, 1, 1), material(vec3(1, 1, 0), 1.0, 1.0, 0.0, 0.0, 0.0) }
};

#define NUM_LIGHTS 1
const light lights[1] = {
	{ vec3(0, 0, 10), vec3(100, 100, 100) }
};

#define NUM_SPOTLIGHTS 0
const spotlight spotlights[1] = {
	{ vec3(-20, 0.0, 10) ,vec3(100, 100, 100), normalize(vec3(4.0, 0.0, -1.0)), PI / 4 }
};

//-------------------------------------------------------
//Primitive intersections.
//-------------------------------------------------------

float intersectSphere(const ray ray, const sphere sphere){
	vec3 rayOriginToSphere = sphere.location - ray.origin;
	float adjacent = dot(rayOriginToSphere, ray.direction);
	if(dot(rayOriginToSphere, rayOriginToSphere) - sphere.radius < epsilon && adjacent > 0)
	{
		return 2 * adjacent;
	}
	else
	{
		vec3 oppositeToSphereOrigin = rayOriginToSphere - adjacent * ray.direction;
		float opposite = dot(oppositeToSphereOrigin, oppositeToSphereOrigin);
		if (opposite > sphere.radius)
			return -1.0;
		else {
			adjacent -= sqrt(sphere.radius - opposite);
			return adjacent;
		};
	}
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
		return distance;
	else
		return -1;
};

//-------------------------------------------------------
//Primitive normal calculations.
//-------------------------------------------------------

vec3 sphereNormal(const sphere sphere, const ray ray, const float distance){
	vec3 rayOriginToSphere = sphere.location - ray.origin;
	vec3 normal = (distance * ray.direction - rayOriginToSphere)/sqrt(sphere.radius);
	float adjacent = dot(rayOriginToSphere, ray.direction);
	if(dot(rayOriginToSphere, rayOriginToSphere) - sphere.radius < epsilon && adjacent > 0)
		return -normal;
	else
		return normal;
}

vec3 planeNormal(const plane plane, const ray ray){
	if (dot(plane.normal, ray.direction) < 0)
		return plane.normal;
	else 
		return -plane.normal;
}

vec3 triangleNormal(const triangle triangle, const ray ray){
	vec3 normal = cross(triangle.e2, triangle.e3);
	if (dot(normal, ray.direction) < 0)
		return normal;
	else
		return -normal;
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
			if(planes[i].texture  == 1){
				//Unfortunately we failed to come up with a method working for all orientations, as therefor this produces square rectangles when the plane has normal vector vec3(0, 0, -1) or vec3(0, 0, 1).
				vec3 pos = ray.origin + ray.direction * distance;
				if( ( int(mod(pos.x , 2)) == 0 && int(mod(pos.y, 2)) ==0 ) || 
				( int(mod(pos.x , 2)) == 1 && int(mod(pos.y, 2)) ==1 )){
					material.color = vec3(1, 1, 1);
				}
				else {
					material.color = vec3(0, 0, 0);
				}
			}
		};
	};
};

void intersectWithTriangles (const ray ray, inout float distance, inout material material, inout vec3 normal){
	for (int i = 0; i < NUM_TRIANGLES; i++) {
		float triangleDistance = intersectTriangle(ray, triangles[i]);
		if (triangleDistance > epsilon && triangleDistance < distance){
			distance = triangleDistance;
			normal = triangleNormal(triangles[i], ray);
			material = triangles[i].material;
		};
	};
};

//-------------------------------------------------------
//Scene shadow ray intersections.
//-------------------------------------------------------

bool intersectWithPlanesShadow(const ray ray, const float distance) {
	for (int i = 0; i < NUM_PLANES; i++) {
		float planeDistance = intersectPlane(ray, planes[i]);
		if (planeDistance > epsilon && (planeDistance < distance)) {
			return true;
		};
	};
	return false;
};

bool intersectWithTrianglesShadow(const ray ray, const float distance) {
	for (int i = 0; i < NUM_TRIANGLES; i++) {
		float triangleDistance = intersectTriangle(ray, triangles[i]);
		if (triangleDistance > epsilon && triangleDistance < distance) {
			return true;
		};
	};
	return false;
};

bool intersectWithSpheresShadow(const ray ray, const float distance) {
	for (int i = 0; i < NUM_SPHERES; i++) {
		float sphereDistance = intersectSphere(ray, spheres[i]);
		if (sphereDistance > epsilon && (sphereDistance < distance)) {
			return true;
		};
	};
	return false;
};


//-------------------------------------------------------
//Utility functions.
//-------------------------------------------------------

float calcReflectionCoefficient(const float n1, const float n2, const float cos_i){
	float R0 = (n1 - n2)/(n1 + n2);
	R0 *=  R0;
	float f = (1 - cos_i);
	return R0 + (1.0 - R0) * f * f * f * f * f;
};

float calcAngleOfRefraction(const float n1, const float n2, const float cos_i){
	float n = n1 / n2;
	float sin_t2 = n * n * (1.0 - cos_i * cos_i);
	return sqrt(1.0 - sin_t2);
}

void updateIntensity(inout ray ray, float distance){
	ray.intensity /= distance * distance;
};

int mostSignificantRay(const ray rayBuffer[RAY_BUFFER_SIZE]){
	int index = 0;
	for(int i = 1; i < RAY_BUFFER_SIZE; i++)
		if(rayBuffer[i].intensity > rayBuffer[index].intensity)
			index = i;

	if(rayBuffer[index].intensity < 0.01)
		return -1;
	else
		return index;
}

int leastSignificantRay(const ray rayBuffer[RAY_BUFFER_SIZE]){
	int index = 0;
	for(int i = 1; i < RAY_BUFFER_SIZE; i++)
		if(rayBuffer[i].intensity < rayBuffer[index].intensity)
			index = i;

	return index;
}

//-------------------------------------------------------
//Scene functions.
//-------------------------------------------------------

//Intersects a ray with the scene
void intersectWithScene(const ray ray, inout float distance, inout vec3 normal, inout material reflectedMaterial)
{
	intersectWithSpheres(ray, distance, reflectedMaterial, normal);
		
	intersectWithPlanes(ray, distance, reflectedMaterial, normal);
	
	intersectWithTriangles(ray, distance, reflectedMaterial, normal);
};

//Intersects a shadow ray with the scene
bool intersectWithSceneShadowRay(const ray ray, const float distance)
{
	if(intersectWithSpheresShadow(ray, distance))
		return true;
	else if(intersectWithPlanesShadow(ray, distance))
		return true;
	else
		return intersectWithTrianglesShadow(ray, distance);
};

//Intersects a ray with the scene
vec3 intersectWithSceneLights(inout ray lightRay)
{
	vec3 calculatedColor = vec3(0, 0, 0);

	for (int i = 0; i < NUM_LIGHTS; i++) {
		vec3 rayOriginToLight = lights[i].location - lightRay.origin;
		float distance = length(rayOriginToLight);
		if (!intersectWithSceneShadowRay(lightRay, distance))
		{
			float adjacent = dot(rayOriginToLight, lightRay.direction);
			vec3 oppositeToLightOrigin = rayOriginToLight - adjacent * lightRay.direction;
			float opposite = dot(oppositeToLightOrigin, oppositeToLightOrigin);
			float intensity = distance * distance;
			if (adjacent > 0)
				intensity *= opposite;
			else
				intensity *= intensity;
			if (intensity > 0)
				calculatedColor += lights[i].color / intensity;
		}
	};

	for (int i = 0; i < NUM_SPOTLIGHTS; i++) {
		vec3 rayOriginToLight = lights[i].location - lightRay.origin;
		float distance = length(rayOriginToLight);

		float spotlightToIntersectionAngle = acos(-dot(rayOriginToLight, spotlights[i].direction));

		if (spotlightToIntersectionAngle < spotlights[i].angle && !intersectWithSceneShadowRay(ray(lightRay.origin, rayOriginToLight / distance, 1.0, 1.0), distance))
		{
			float adjacent = dot(rayOriginToLight, lightRay.direction);
			vec3 oppositeToLightOrigin = rayOriginToLight - adjacent * lightRay.direction;
			float opposite = dot(oppositeToLightOrigin, oppositeToLightOrigin);
			float intensity = (opposite + adjacent * adjacent) * opposite;
			if (intensity > 0)
				calculatedColor += lights[i].color / intensity;
		}
	};

	return calculatedColor;
};

//Calculates the shadow rays for any given point. 
vec3 intersectShadowRays(vec3 origin, vec3 direction, float specularHardness, vec3 surfaceNormal){
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
			
			ray shadowRay = ray(origin, originToLight, 1.0, 1.0);
					
			if (!intersectWithSceneShadowRay(shadowRay, distanceToLight)){
				updateIntensity(shadowRay, distanceToLight);
				float diffuseIntensity = shadowRay.intensity * angle;

				vec3 h = normalize(originToLight - direction);
				float nDotH = dot(surfaceNormal, h);
				float specularIntensity = shadowRay.intensity * pow(max(nDotH, 0.0), specularHardness);
				
				calculatedColor += lights[i].color * (diffuseIntensity + specularIntensity);
			}
		}
	}
	
	for (int i = 0; i < NUM_SPOTLIGHTS; i++) {
		originToLight = spotlights[i].location - origin;

		angle = dot(originToLight, surfaceNormal);

		if (angle > 0)
		{
			distanceToLight = sqrt(dot(originToLight, originToLight));
			originToLight /= distanceToLight;

			float spotlightToIntersectionAngle = acos(-dot(originToLight, spotlights[i].direction));

			if (spotlightToIntersectionAngle < spotlights[i].angle)
			{
				angle = dot(originToLight, surfaceNormal);

				ray shadowRay = ray(origin, originToLight, 1.0, 1.0);

				if (!intersectWithSceneShadowRay(shadowRay, distanceToLight)) {
					updateIntensity(shadowRay, distanceToLight);
					float diffuseIntensity = shadowRay.intensity * angle;

					vec3 h = normalize(originToLight + direction);
					float nDotH = dot(surfaceNormal, h);
					float specularIntensity = shadowRay.intensity * pow(max(nDotH, 0.0), specularHardness);

					calculatedColor += lights[i].color * (diffuseIntensity + specularIntensity);
				}
			}
		}
	}

	return calculatedColor;
};

//Because glsl doesn't allow recursion, a loop is needed to calculate the color.
vec3 intersectWithSceneIterator(ray primaryRay)
{
	vec3 inputRayColor = vec3(0, 0, 0);
	
	vec3 normal;
	material reflectedMaterial;
	
	float distance;
	
	vec3 intersectionLocation;
		
	ray rayBuffer[RAY_BUFFER_SIZE];

	for (int i = RAYS_PER_PIXEL_VERTICAL * RAYS_PER_PIXEL_HORIZONTAL; i < RAY_BUFFER_SIZE; i++)
		rayBuffer[i] = ray(vec3(0, 0, 0), vec3(0, 0, 0), 0.0, 0.0);

	for (int i = 0; i < RAYS_PER_PIXEL_VERTICAL; i++)
		for (int j = 0; j < RAYS_PER_PIXEL_HORIZONTAL; j++)
			rayBuffer[i * RAYS_PER_PIXEL_VERTICAL + j] = ray(primaryRay.origin, primaryRay.direction + (i / (windowSize.x * RAYS_PER_PIXEL_VERTICAL)) * dRight + (j / (windowSize.y * RAYS_PER_PIXEL_VERTICAL)) * dUp, primaryRay.intensity / (RAYS_PER_PIXEL_VERTICAL * RAYS_PER_PIXEL_HORIZONTAL), primaryRay.r_index);
	
    rayBuffer[0] = primaryRay;
	
	ray currentray;
		
	int index = 0;
					
	for(int i = 0; i < 20; i++)
	{	
		distance = maxDistance;
				
		index = mostSignificantRay(rayBuffer);
				
		if(index == -1)
			break;
			
		currentray = rayBuffer[index];
		
		rayBuffer[index].intensity = 0;

		inputRayColor += intersectWithSceneLights(currentray) * currentray.intensity;
		
		intersectWithScene(currentray, distance, normal, reflectedMaterial);
								
		//if the distance to intersection is too large, pretent it doesn't intersect.
		if(distance < maxDistance){
			intersectionLocation = currentray.origin + currentray.direction * distance;
			
			if(reflectedMaterial.diffuse > epsilon){
				vec3 shadowColor = intersectShadowRays(currentray.origin + currentray.direction * distance, currentray.direction, reflectedMaterial.specularHardness, normal);
				inputRayColor += reflectedMaterial.diffuse * shadowColor * currentray.intensity * reflectedMaterial.color;
			};
			
			if(reflectedMaterial.reflectivity > epsilon){
				rayBuffer[leastSignificantRay(rayBuffer)] = ray(intersectionLocation, currentray.direction - 2 * dot(currentray.direction, normal) * normal, currentray.intensity * reflectedMaterial.reflectivity, currentray.r_index);
			};
			
			if(reflectedMaterial.emitance > epsilon)
			{
				//the following code was derived from https://graphics.stanford.edu/courses/cs148-10-summer/docs/2006--degreve--reflection_refraction.pdf
				float R0 = reflectedMaterial.emitance;
				
				float cos_i = -dot(currentray.direction, normal);
									
				float n2 = 1.0;
				if (currentray.r_index != reflectedMaterial.r_index)
					n2 = reflectedMaterial.r_index;
				
				//check for total internal reflection, if yes launch reflectedray.
				if(sqrt(1.0 - cos_i * cos_i) > n2 / currentray.r_index && currentray.r_index > n2)
					rayBuffer[leastSignificantRay(rayBuffer)] = ray(intersectionLocation,currentray.direction - 2 * dot(currentray.direction, normal) * normal, currentray.intensity * R0, currentray.r_index);
				else
				{
					float cos_t = calcAngleOfRefraction(currentray.r_index, n2, cos_i);
					if(currentray.r_index <= n2)
						R0 *= calcReflectionCoefficient(currentray.r_index, n2, cos_i);
					else
						R0 *= calcReflectionCoefficient(currentray.r_index, n2, cos_t);
																				
					rayBuffer[leastSignificantRay(rayBuffer)] = ray(intersectionLocation, (currentray.r_index / n2) * (currentray.direction + cos_i * normal) - cos_t * normal, currentray.intensity * (1 - R0), n2);
					
					rayBuffer[leastSignificantRay(rayBuffer)] = ray(intersectionLocation,currentray.direction - 2 * dot(currentray.direction, normal) * normal, currentray.intensity * R0, currentray.r_index);						
				}
			}
		}
		else
		{
			rayBuffer[index].intensity = 0;
			vec2 uv = vec2(atan(currentray.direction.y, currentray.direction.x) / (2 * PI) + 0.5, acos(currentray.direction.z) / PI);
			inputRayColor += currentray.intensity * vec3(texture2D(skydome, uv));
		}
	}
	
	return inputRayColor;
}


//-------------------------------------------------------
//Debug functions.
//-------------------------------------------------------

//Intersects a pixel in screen space.
bool intersectWithVector(vec2 pixelPosition, vec2 rayOrigin, vec2 screen_space_intersection) {
	vec2 rayOriginToPixelPosition = pixelPosition - rayOrigin;
	vec2 rayIntersectDir = screen_space_intersection - rayOrigin;

	float dot_product = dot(normalize(rayOriginToPixelPosition), rayIntersectDir);
	if (0 < dot_product && length(rayOriginToPixelPosition) < dot_product) {
		float dot_product_2 = dot(rayOriginToPixelPosition, normalize(rayIntersectDir));
		float cross_product = dot(rayOriginToPixelPosition, rayOriginToPixelPosition) - dot_product_2 * dot_product_2;
		if (cross_product < 0.0001)
			return true;
	}
	return false;
}

//Intersects shadow rays with the scene. inShadow = true if the pixelPosition is inside the shadowRay, inShadowHit returns true if both inShadow and the shadow ray hit an object.
//This function requires a dedicated debug function because inserting a handle inside the original function would result in performance loss.
void intersectDebugShadowRay(vec2 pixelPosition, vec3 intersectLocaction, vec3 sufaceNorm, out bool inShadow, out bool inShadowHit) {
	vec3 originToLight;
	float distanceToLight;

	inShadow = false;
	inShadowHit = false;

	for (int i = 0; i < NUM_LIGHTS; i++) {
		originToLight = lights[i].location - intersectLocaction;

		distanceToLight = sqrt(dot(originToLight, originToLight));

		if (distanceToLight < 100 && intersectWithVector(pixelPosition, vec2(debugTransformationMatrix * vec4(intersectLocaction, 1.0)), vec2(debugTransformationMatrix * vec4(lights[i].location, 1.0))))
		{
			inShadow = true;

			float angle = dot(originToLight, sufaceNorm);

			if (angle > 0)
			{
				originToLight /= distanceToLight;

				ray shadowRay = ray(intersectLocaction, originToLight, 1.0, 1.0);

				if (intersectWithSceneShadowRay(shadowRay, distanceToLight)) {
					inShadowHit = true;
					return;
				}
			}
		}
	}
}

//Intersects ray with the scene.
//This function requires a dedicated debug function because inserting a handle inside the original function would result in performance loss.
void intersectDebugRay(ray primaryRay, vec2 pixelDirection, out bool intersection, out vec3 color) {
	vec3 intersectionNormal;
	material reflectedMaterial;
	float distance = maxDistance;

	intersection = false;

	intersectWithScene(primaryRay, distance, intersectionNormal, reflectedMaterial);

	vec2 screenSpaceRayOrigin = vec2(debugTransformationMatrix * vec4(primaryRay.origin, 1.0));

	vec2 screenSpaceIntersection = vec2(debugTransformationMatrix * vec4((distance * primaryRay.direction + primaryRay.origin), 1.0));

	if (intersectWithVector(pixelDirection, screenSpaceRayOrigin, screenSpaceIntersection)) {
		intersection = true;
		color = vec3(1.0, 1.0, 0.0);
	}

	else if (reflectedMaterial.diffuse > 0) {
		bool inShadow;
		bool inShadowHit;

		intersectDebugShadowRay(pixelDirection, distance * primaryRay.direction + primaryRay.origin, intersectionNormal, inShadow, inShadowHit);

		if (inShadow)
		{
			intersection = true;
			color = vec3(0.0, 1.0, 1.0);
			if (inShadowHit)
				color = vec3(0.0, 0.5, 0.5);
		}
	}

	if (!intersection && reflectedMaterial.reflectivity > 0) {
		primaryRay = ray(distance * primaryRay.direction + primaryRay.origin, primaryRay.direction - 2 * dot(primaryRay.direction, intersectionNormal) * intersectionNormal, 1.0, 1.0);
		distance = maxDistance;
		intersectWithScene(primaryRay, distance, intersectionNormal, reflectedMaterial);

		screenSpaceRayOrigin = vec2(debugTransformationMatrix * vec4(primaryRay.origin, 1.0));

		screenSpaceIntersection = vec2(debugTransformationMatrix * vec4((distance * primaryRay.direction + primaryRay.origin), 1.0));

		if (intersectWithVector(pixelDirection, screenSpaceRayOrigin, screenSpaceIntersection)) {
			intersection = true;
			color = vec3(0.5, 0.5, 0.0);
		}

	}
}

//Renders the primitives to the debug.
vec3 renderDebugPrimitives(vec2 pixelDirection) {
	vec3 color = vec3(0, 0, 0);

	for (int i = 0; i < NUM_SPHERES; i++) {
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

	return vec4(color, 1.0);
};

void main() {
	vec4 pixelLocation = gl_FragCoord;
	vec2 pixelPosition = vec2(pixelLocation.x / windowSize.x, pixelLocation.y / windowSize.y);

	if (!renderDebug) {
		vec3 direction = normalize(dBotLeft + pixelPosition.x * dRight + pixelPosition.y * dUp);
		outputColor = getRayColor(ray(camLocation, direction, 1.0, 1.0));
	}
	else {
		bool inRay;
		vec3 color;

		vec2 pixelDirection = vec2((pixelPosition.y - 0.2) * 10, (pixelPosition.x - 0.5) * 10);

		vec3 direction = normalize(dBotLeft + dRight / 2 + dUp / 2);

		intersectDebugRay(ray(camLocation, direction, 1.0, 1.0), pixelDirection, inRay, color);

		if (!inRay)
			color = renderDebugPrimitives(pixelDirection), 1.0;

		outputColor = vec4(color, 1.0);
	}
};