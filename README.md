# Matcap-Shader
Lightweight matcap shader for mobile Unity apps with normal map and primitive specular map support.

  RGBAMix Matcap Spin.png is the matcap used for lighting. Each channel (red, green, blue, alpha) corresponds to
either the highlights or shadows of either a matte or a shiny surface.

  Roomexample.png, Cratecompare.png, and Pipecompare.png show what the shader's output looks like using the provided
matcap.

  WallSet3 Albedo Dark.png and WallSet3 Normal Trimmed.png are texture files that can be used to test this Matcap.
  
  This shader is NOT suitable for scenes in which the camera rotates, as all lighting is camera-dependent.
