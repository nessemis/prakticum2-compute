Team members,
Cody Arets: 5910137
Dennis Arets: 6051529

First of, our entire submission uses glsl 4.3. We unfortunately forgot to check if the computers in the practicum
-room support this version. We did test this application on intel hd4600 graphics, a nvidia geforce gtx 780m,
and a nvidia geforce gtx 960m. For the best experience, we recommend utilizing a dedicated graphics card. Using
the 780m we were able to get north of 60fps in the full-fledged shader, and around 4000 fps on the fast shader.
Because we use incremental translation and rotation for movement, we had to limit the fps. (at 4000 fps, you
would otherwise move about 8 times as fast). Also, although we tried to keep the shader source code as 
organized as possible, opengl is not object oriented. The shader should be readable, but it is basically a 
very large class with very few object-oriented methods to deal with problems.
The program starts off using the fast shader.

Lastly, we made this project using github, the following link is the repository
https://github.com/nessemis/prakticum2-compute.

Cody Arets is doycie.
Dennis Arets is nessemis.

------------------------------------------------

Features:
1. gpgpu implementation.
2. triangle support.
3. spotlights.
4. anti-alialiasing.
5. skydome (this is implemented in the gpgpu shader, so that should be +2 points?)
6. refraction.
7. (blin phong shading).
7. (ambient light source illumination and light source visuals).
8. (fastest raytracer perhaps...).

missing:
1. A good debug view. Using the fragment shaders provides a per-pixel interface to the display, which makes 
drawing lines very hard. We managed to implement a simple debug view only rendering spheres (with rotation to match
different camera rotations and angles). It renders the ray at the center of the screen and intersects spheres
with a plane in the center of the screen.
2. Technically there is no recursion in this ray tracer, because we use a for loop (again, glsl doesn't allow
for recursion). This approach is functionally idententical.
3. changing a tiled plane's normal vector skews the tiled pattern.

basic controls:
awsd, translates the camera position (intuitively).
arrows, rotates the camera (also intuitive).
q and e, moves the camera up and down.
1 and 2, changes the camera angle.
3 and 4, toggle debug view.

Because our goal was to make the shader as fast as possible while implementing the needed functionality (and making it look beautifull), 
some functions might be harder to acces than for other shaders.

1. modifying the scene has to be done inside the fragment shader (fs.glsl and fs-fast.glsl). We used this approach
to maximize fps as the scene is basically pre-baked in the shader upon load. Scene modification is flexible though,
and not to complex as the scene declaration is grouped together.
2. Anti aliasing has to be enabled in the shader. Modify RAYS_PER_PIXEL_VERTICAL and RAYS_PER_PIXEL_HORIZONTAL
for the best anti-aliassing experience.
3. changing between the fast and the beautifull raytracing can be done by modifying the bool FAST_RAY_TRACER
inside the window.cs class.

Sources used:
https://codeyarns.com/2013/06/07/how-to-get-started-with-opentk-using-c-and-visual-studio/ --Setting up the window
https://www.cs.uaf.edu/2010/spring/cs481/section/1/lecture/02_11_recursive.html --implementing 'recursion' in glsl.
https://graphics.stanford.edu/courses/cs148-10-summer/docs/2006--degreve--reflection_refraction  --Implementing refraction
https://en.wikipedia.org/wiki/Blinn%E2%80%93Phong_shading_model --blin phong shading.
https://www.stackoverflow.com --for everything else ;)
