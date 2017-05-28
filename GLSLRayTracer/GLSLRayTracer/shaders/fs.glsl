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

#define epsilon 0.0005

#define minimumIntensity 0.0001

#define RAY_BUFFER_SIZE 10

#define maxDistance 10000000000.0

//-------------------------------------------------------
//Primitives.
//-------------------------------------------------------

struct light{
	vec3 location;
	vec3 color;
};

struct spotlight{
    vec3 location;
    vec3 direction;
    float angle;

};

struct material{
	vec3 color;
	float diffuse;
	float reflectivity;
	float emitance;
	//refractive index;
	float r_index;
};

struct ray{
	vec3 origin;
	vec3 direction;
	float intensity;
	float r_index;
};

struct sphere{
	vec3 location;
	//insert the radius squared in this field.
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
	vec3 normal = (distance * ray.direction - rayOriginToSphere)/sphere.radius;
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
//Scene declarations.
//-------------------------------------------------------

#define NUM_SPHERES 3
const sphere spheres[3] = {
	{vec3(4, -1.5, 0), 1.0, material(vec3(1, 0, 0), 0.0, 0.0, 1.0, 1.0)},
	{vec3(4, 1.5, 0), 1.0, material(vec3(0, 1, 0), 0.0, 0.0, 1.0, 1.1)},
	{vec3(6, 0, 0), 1.0, material(vec3(1, 1, 0), 1.0, 0.0, 0.0, 1.0)}
};

#define NUM_PLANES 3
const plane planes[3] = {
	{vec3(0, 0, -1), 1.0, material(vec3(1, 0, 0), 0.5, 1.0, 0.0, 1.0)},
	{vec3(0, -1, 0), 4.0, material(vec3(0, 1, 0), 1.0, 0.0, 0.0, 1.0)},
	{vec3(0, 1, 0), 4.0, material(vec3(0, 0, 1), 1.0, 0.0, 0.0, 1.0)}
};

#define NUM_TRIANGLES 0
const triangle triangles[1] = {
	{vec3(2, -1, 0), vec3(0, 2, 0), vec3(0, 1, 1), material(vec3(1, 1, 0), 1.0, 0.0, 0.0, 0.0)}
};

#define NUM_LIGHTS 1
const light lights[1] = {
	{vec3(0, 0, 5), vec3(10000, 10000, 10000)}
};

#define NUM_SPOTLIGHTS 1
const spotlight spotlights[1] = {
	{vec3(0,0,2),vec3(0,1,0), -0.76 }
};

//-------------------------------------------------------
//Scene intersections.
//-------------------------------------------------------

void intersectWithSpheres (inout ray ray, inout float distance, inout material material, inout vec3 normal){
	for (int i = 0; i < NUM_SPHERES; i++) {
		float sphereDistance = intersectSphere(ray, spheres[i]);
		if (sphereDistance > epsilon && (sphereDistance < distance)){
			distance = sphereDistance;
			normal = sphereNormal(spheres[i], ray, distance);
			material = spheres[i].material;
		};
	};
};

bool intersectWithSpheresShadow (inout ray ray, inout float distance){
	for (int i = 0; i < NUM_SPHERES; i++) {
		float sphereDistance = intersectSphere(ray, spheres[i]);
		if (sphereDistance > epsilon && (sphereDistance < distance)){
			return true;
		};
	};
	return false;
};

void intersectWithPlanes (inout ray ray, inout float distance, inout material material, inout vec3 normal){
	for (int i = 0; i < NUM_PLANES; i++) {
		float planeDistance = intersectPlane(ray, planes[i]);
		if (planeDistance > epsilon && (planeDistance < distance)){
			distance = planeDistance;
			normal = planeNormal(planes[i], ray);
			material = planes[i].material;
		};
	};
};

bool intersectWithPlanesShadow (inout ray ray, const float distance){
	for (int i = 0; i < NUM_PLANES; i++) {
		float planeDistance = intersectPlane(ray, planes[i]);
		if (planeDistance > epsilon && (planeDistance < distance)){
			return true;
		};
	};
	return false;
};

void intersectWithTriangles (inout ray ray, inout float distance, inout material material, inout vec3 normal){
	for (int i = 0; i < NUM_TRIANGLES; i++) {
		float triangleDistance = intersectTriangle(ray, triangles[i]);
		if (triangleDistance > epsilon && triangleDistance < distance){
			distance = triangleDistance;
			normal = triangleNormal(triangles[i], ray);
			material = triangles[i].material;
		};
	};
};

bool intersectWithTrianglesShadow (inout ray ray, const float distance){
	for (int i = 0; i < NUM_TRIANGLES; i++) {
		float triangleDistance = intersectTriangle(ray, triangles[i]);
		if (triangleDistance > epsilon && triangleDistance < distance){
			return true;
		};
	};
	return false;
};

//-------------------------------------------------------
//Utility functions.
//-------------------------------------------------------

float calcReflectionCoefficient(const float n1, const float n2, const float cos_a){
	float R0 = (n1 - n2)/(n1 + n2);
	R0 *=  R0;
	float f = (1 - cos_a);
	return R0 + (1 - R0) * f * f * f * f * f;
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

void intersectWithScene(inout ray ray, inout float distance, inout vec3 normal, inout material reflectedMaterial)
{
	intersectWithSpheres(ray, distance, reflectedMaterial, normal);
		
	intersectWithPlanes(ray, distance, reflectedMaterial, normal);
	
	intersectWithTriangles(ray, distance, reflectedMaterial, normal);
};

bool intersectWithSceneShadowRay(inout ray ray, inout float distance)
{
	if(intersectWithSpheresShadow(ray, distance))
		return true;
	else if(intersectWithPlanesShadow(ray, distance))
		return true;
	else
		return intersectWithTrianglesShadow(ray, distance);
}

vec3 launchShadowRays(vec3 origin, vec3 incomingDirection, vec3 surfaceNormal){
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
			
			ray shadowRay = ray(origin, originToLight, 1.0, 1.0);
					
			if (!intersectWithSceneShadowRay(shadowRay, distanceToLight)){
				updateIntensity(shadowRay, distanceToLight);
				shadowRay.intensity *= angle;
				
				updateIntensity(shadowRay, distanceToLight);
				calculatedColor += lights[i].color * shadowRay.intensity;
			}
		}
	}
	for(int i = 0; i < NUM_SPOTLIGHTS;i++){
        originToLight = spotlights[i].location - origin;

        distanceToLight = sqrt(dot(originToLight, originToLight));
        originToLight /= distanceToLight;

        float dirdis = sqrt(dot(spotlights[i].direction,spotlights[i].direction));
        vec3 dir = spotlights[i].direction/dirdis;

        float angle = dot( originToLight , dir);
        if(angle > spotlights[i].angle ){
                calculatedColor  *= 0.1;
        }else{
                calculatedColor *= 1;
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
		
	ray rayBuffer[RAY_BUFFER_SIZE];
	
	for(int i = 0; i < RAY_BUFFER_SIZE; i++){
		rayBuffer[i] = ray(vec3(0, 0, 0), vec3(0, 0, 0), 0, 0);
	}
	
    rayBuffer[0] = primaryRay;
	
	ray currentray;
		
	int index = 0;
					
	for(int i = 0; i < 10; i++)
	{	
		distance = maxDistance;
				
		index = mostSignificantRay(rayBuffer);
				
		if(index == -1)
			break;
			
		currentray = rayBuffer[index];
		
		rayBuffer[index].intensity = 0;
		
		intersectWithScene(currentray, distance, normal, reflectedMaterial);
								
		//if the distance to intersection is too large, pretent it doesn't intersect.
		if(distance < maxDistance){
			intersectionLocation = currentray.origin + currentray.direction * distance;
			
			if(reflectedMaterial.diffuse > epsilon){
				vec3 shadowColor = launchShadowRays(currentray.origin + currentray.direction * distance, currentray.direction, normal);
				inputRayColor += reflectedMaterial.diffuse * shadowColor * currentray.intensity * reflectedMaterial.color;
			};
			
			if(reflectedMaterial.reflectivity > epsilon){
				rayBuffer[index] = ray(intersectionLocation, currentray.direction - 2 * dot(currentray.direction, normal) * normal, currentray.intensity * reflectedMaterial.reflectivity, currentray.r_index);
			};
			
			if(reflectedMaterial.emitance > epsilon)
			{
				//the following code was derived from https://graphics.stanford.edu/courses/cs148-10-summer/docs/2006--degreve--reflection_refraction.pdf
				float R0 = reflectedMaterial.emitance;
				
				float cos_i = dot(-currentray.direction, normal);
									
				float n2 = 1.0;
				if (currentray.r_index != reflectedMaterial.r_index)
					n2 = reflectedMaterial.r_index;
				
				//check for total internal reflection, if yes launch reflectedray.
				if(sin(acos(cos_i)) > n2 / currentray.r_index && currentray.r_index > n2)
					rayBuffer[leastSignificantRay(rayBuffer)] = ray(intersectionLocation,currentray.direction - 2 * dot(currentray.direction, normal) * normal, currentray.intensity * R0, currentray.r_index);
				else
				{
					float cos_t = cos(calcAngleOfRefraction(currentray.r_index, n2, acos(cos_i)));
					if(currentray.r_index <= n2)
						R0 *= calcReflectionCoefficient(currentray.r_index, n2, cos_i);
					else
						R0 *= calcReflectionCoefficient(currentray.r_index, n2, cos_t);
																				
					rayBuffer[leastSignificantRay(rayBuffer)] = ray(intersectionLocation, (currentray.r_index / n2) * (currentray.direction + (cos_i - cos_t) * normal), currentray.intensity * (1 - R0), n2);
					
					rayBuffer[leastSignificantRay(rayBuffer)] = ray(intersectionLocation,currentray.direction - 2 * dot(currentray.direction, normal) * normal, currentray.intensity * R0, currentray.r_index);						
				}
			}
		}
		else
			rayBuffer[index].intensity = 0;

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

	//we assume the camera doesn't start inside the object.
	outputColor = getRayColor(ray(camLocation, direction, 1.0, 1.0));
};