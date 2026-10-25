// "HD": suaviza as bordas serrilhadas dos sprites (estilo FXAA simples) e realça um pouco as cores.
// Só atua onde há contraste forte entre vizinhos, então o interior dos sprites fica nítido.
// Ajuste as constantes abaixo ao gosto.
uniform vec2 u_Resolution;
uniform sampler2D u_Tex0;
varying vec2 v_TexCoord;

const float EDGE_THRESHOLD = 0.05; // abaixo disso não suaviza (menor = suaviza mais regiões)
const float SMOOTHING = 0.65;      // 0 = nada, 1 = suavização máxima nas bordas
const float SHARPEN = 0.15;        // realce do interior dos sprites
const float SATURATION = 1.12;     // 1 = cor original

float luma(vec3 c)
{
  return dot(c, vec3(0.299, 0.587, 0.114));
}

void main(void)
{
  vec2 px = 1.0 / u_Resolution;

  vec3 c  = texture2D(u_Tex0, v_TexCoord).rgb;
  vec3 n  = texture2D(u_Tex0, v_TexCoord + vec2(0.0, -px.y)).rgb;
  vec3 s  = texture2D(u_Tex0, v_TexCoord + vec2(0.0,  px.y)).rgb;
  vec3 e  = texture2D(u_Tex0, v_TexCoord + vec2( px.x, 0.0)).rgb;
  vec3 w  = texture2D(u_Tex0, v_TexCoord + vec2(-px.x, 0.0)).rgb;
  vec3 ne = texture2D(u_Tex0, v_TexCoord + vec2( px.x, -px.y)).rgb;
  vec3 nw = texture2D(u_Tex0, v_TexCoord + vec2(-px.x, -px.y)).rgb;
  vec3 se = texture2D(u_Tex0, v_TexCoord + vec2( px.x,  px.y)).rgb;
  vec3 sw = texture2D(u_Tex0, v_TexCoord + vec2(-px.x,  px.y)).rgb;

  float lc = luma(c);
  float lmin = min(lc, min(min(luma(n), luma(s)), min(luma(e), luma(w))));
  float lmax = max(lc, max(max(luma(n), luma(s)), max(luma(e), luma(w))));
  float contrast = lmax - lmin;

  vec3 blur = (c * 4.0 + (n + s + e + w) * 2.0 + ne + nw + se + sw) / 16.0;
  vec3 sharp = c + (c - blur) * SHARPEN;

  // Borda -> mistura com o desfoque; interior -> realce leve.
  float edge = smoothstep(EDGE_THRESHOLD, EDGE_THRESHOLD * 4.0, contrast);
  vec3 col = mix(sharp, blur, edge * SMOOTHING);

  float l = luma(col);
  col = mix(vec3(l), col, SATURATION);

  gl_FragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
