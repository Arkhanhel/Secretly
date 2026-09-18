#version 460 core
// black_hole.frag — гравитационное линзирование Шварцшильда для Flutter.
// Та же математика, что в bh_proto: интегрирование нулевых геодезических,
// аккреционный диск с доплеровским усилением, фотонное кольцо, тень.
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uTime;
uniform float uQuality; // 1.0 = качество, 0.6..0.8 — быстрее (крупнее шаг)
// Слой отрисовки: 0 = всё (обычная обложка), 1 = ТОЛЬКО ближняя (передняя)
// половина диска на прозрачном фоне — рисуется ПОВЕРХ фото профиля,
// 2 = всё КРОМЕ ближней половины (тень, дальние арки, звёзды) — ПОД фото.
// Вместе слои 1+2 дают эффект «фото внутри чёрной дыры».
uniform float uLayer;

out vec4 fragColor;

const float RS = 1.0, RIN = 2.6, ROUT = 11.0, CAMR = 16.0;
const int STEPS = 150;

float hash13(vec3 p){ p = fract(p * 0.1031); p += dot(p, p.yzx + 33.33); return fract((p.x + p.y) * p.z); }

vec3 diskRamp(float t){
  vec3 cw = vec3(1.35, 1.28, 1.18), ca = vec3(1.15, 0.62, 0.22), cr = vec3(0.55, 0.16, 0.05);
  return t < 0.35 ? mix(cw, ca, t / 0.35) : mix(ca, cr, (t - 0.35) / 0.65);
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 uv = (frag / uSize * 2.0 - 1.0);
  uv.x *= uSize.x / uSize.y;

  // Frame the hole for a profile COVER: enlarge it and lift it up so the avatar
  // photo (upper-centre of the banner) ends up inside the dark event horizon.
  // Two knobs — ZOOM (<1 = bigger hole) and LIFT (larger = hole sits higher).
  // Калибровка по реальному профилю (скрин 1080×2400): центр фото ≈ 44% высоты
  // обложки, радиус фото ≈ 0.32·(H/2) → тень должна накрыть фото с запасом.
  // ZOOM подобран так, что ЧЁРНАЯ тень горизонта совпадает с краем фото
  // профиля (тень uv ≈ 0.155/zoom = радиус фото 0.317) — фотонное кольцо
  // светится сразу за рамкой, а вся дыра видна почти целиком.
  vec2 duv = uv * 0.60;   // ZOOM: smaller = bigger black hole
  duv.y += 0.072;         // LIFT: larger = hole higher in the frame

  // Лёгкое дыхание камеры (амплитуда мала, чтобы тень не съезжала с фото).
  float incl = radians(83.0) + sin(uTime * 0.11) * 0.012;
  float yaw = uTime * 0.045;
  vec3 ro = vec3(sin(yaw) * CAMR * sin(incl), CAMR * cos(incl), -cos(yaw) * CAMR * sin(incl));
  vec3 fwd = normalize(-ro);
  vec3 rgt = normalize(cross(fwd, vec3(0.0, 1.0, 0.0)));
  vec3 up = cross(rgt, fwd);
  vec3 rd = normalize(fwd + 1.05 * (duv.x * rgt - duv.y * up));

  vec3 pos = ro, vel = rd;
  vec3 hv = cross(pos, vel);
  float h2 = dot(hv, hv);
  float baseDt = 0.30 / max(uQuality, 0.4);

  vec3 col = vec3(0.0);
  bool escaped = false;

  for (int i = 0; i < STEPS; i++) {
    float r = length(pos);
    if (r < RS * 1.02) break;                                   // горизонт событий
    if (r > CAMR * 2.2 && dot(pos, vel) > 0.0 && i > 30) { escaped = true; break; }
    float dt = baseDt * clamp(r / 3.0, 0.25, 1.6);
    vec3 acc = -1.5 * RS * h2 * pos / pow(r, 5.0);              // геодезическое отклонение
    vec3 nv = vel + acc * dt;
    vec3 np = pos + nv * dt;
    if (pos.y * np.y < 0.0) {                                   // пересечение плоскости диска
      float f = pos.y / (pos.y - np.y);
      vec3 hit = mix(pos, np, f);
      float rr = length(hit.xz);
      // Ближняя (передняя) половина диска = точка на камере-стороне от дыры.
      float nearSide = dot(hit, ro);
      bool passLayer = uLayer < 0.5
          || (uLayer < 1.5 ? nearSide > 0.0 : nearSide <= 0.0);
      if (passLayer && rr > RIN && rr < ROUT) {
        float phi = atan(hit.z, hit.x);
        float ang = phi + uTime * 0.5 / pow(rr, 1.5);           // дифференциальное вращение
        float streaks = 0.62 + 0.38 * (0.55 * sin(ang * 7.0 + log(rr) * 11.0)
                                     + 0.30 * sin(ang * 17.0 + rr * 3.0 + 1.7)
                                     + 0.15 * sin(ang * 29.0 - rr * 7.0 + 4.1));
        float t01 = clamp((rr - RIN) / (ROUT - RIN), 0.0, 1.0);
        float bright = pow(1.0 - t01, 1.6) * 1.35 + 0.06;
        float edge = clamp((rr - RIN) / 0.5, 0.0, 1.0) * clamp((ROUT - rr) / 2.6, 0.0, 1.0);
        vec3 em = diskRamp(t01) * (streaks * bright * edge);
        float vmag = sqrt(0.5 * RS / max(rr, 1e-3));            // кеплеровская скорость
        vec3 tang = vec3(-sin(phi), 0.0, cos(phi));
        float vd = -dot(tang, normalize(-vel)) * vmag;
        float beam = pow(clamp(1.0 + 2.2 * vd, 0.25, 2.6), 3.0); // релятивистское усиление
        float gsh = sqrt(clamp(1.0 - RS / max(rr, 1e-3), 0.05, 1.0));
        em *= beam * gsh;
        em *= 1.0 + clamp(vd * 1.6, 0.0, 1.0) * vec3(0.0, 0.12, 0.35);
        col += em * 0.85;
      }
    }
    pos = np; vel = nv;
  }

  // Звёзды — только в полном (0) и заднем (2) слоях; передний слой прозрачен.
  if (escaped && (uLayer < 0.5 || uLayer > 1.5)) {               // линзированный звёздный фон
    vec3 d = normalize(vel);
    vec3 cell = floor(d * 360.0);   // finer grid → smaller stars
    float h = hash13(cell);
    if (h > 0.9982) {               // sparser, to match the finer grid
      float h2s = hash13(cell + 7.31);
      col += (0.3 + h2s * 0.7) * 0.95 * vec3(0.9 + 0.1 * h2s, 0.9, 1.0 - 0.15 * h2s) * 0.9;
    }
  }

  col = col / (1.0 + col) * 1.25;                                // тонмаппинг
  vec3 outc = pow(clamp(col, 0.0, 1.0), vec3(1.0 / 2.2));
  // Передний слой: прозрачен ТОЛЬКО там, где газа нет совсем. Внутри полосы
  // диска альфа резко насыщается (pow+буст), чтобы газ был плотным и почти не
  // просвечивал фото за ним; мягкими остаются лишь самые края. Premultiplied
  // остаётся корректным: каждый канал ≤ альфы (a ≥ maxc всегда).
  float a = 1.0;
  if (uLayer > 0.5 && uLayer < 1.5) {
    float maxc = max(outc.r, max(outc.g, outc.b));
    a = clamp(pow(maxc, 0.55) * 2.0, 0.0, 1.0);
  }
  fragColor = vec4(outc, a);
}
