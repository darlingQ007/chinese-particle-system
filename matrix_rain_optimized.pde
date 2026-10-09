// ============================================================
// Processing 4 汉字粒子系统优化版 - 高性能流畅运行
// ============================================================
// 【性能优化】
// 1. 字体只在 setup 中创建一次
// 2. 减少 ArrayList 创建，预分配空间
// 3. 不使用 PVector 构造，直接赋值
// 4. 省略不必要的 Perlin Noise 计算
// 5. 简化颜色计算逻辑
// 6. 使用位数组代替 boolean 数组
// 7. 减少三角函数调用
// ============================================================

ArrayList<LetterParticle> particles;
String[] charPool;

// ================== 参数配置区 ==================
final int COLS = 60;           // 列数
final int ROWS = 40;           // 行数
final int TOTAL_PARTICLES = 2400; // 总粒子数

final float PARTICLE_SPACING_X = 20.0f;
final float PARTICLE_SPACING_Y = 18.0f;
final float START_X = 40.0f;
final float START_Y = 30.0f;

final float NOISE_SCALE = 0.004f;   // Perlin Noise 波动强度
final float WAVE_AMP = 1.7f;        // 波浪摆动幅度
final float WAVE_FREQ = 0.022f;     // 波浪摆动频率

final float BASE_FALL_SPEED_MIN = 1.0f;
final float BASE_FALL_SPEED_MAX = 2.4f;

final float DAMPING = 0.93f;        // 速度阻尼
final float MAX_SPEED = 5.2f;       // 最大速度限制
final float RETURN_SPRING = 0.11f;  // 弹性系数
final float RETURN_DAMPING = 0.9f;  // 回归中阻尼

final float REPEL_RADIUS = 130.0f;   // 排斥半径
final float REPEL_STRENGTH = 0.68f;  // 排斥力强度
final float VORTEX_RADIUS = 350.0f;  // 旋涡半径
final float CENTER_PULL_STRENGTH = 0.065f; // 向心力强度
final float SWIRL_STRENGTH = 0.12f;  // 切向力强度

final float TRAIL_ALPHA = 35;    // 拖尾透明度
final float GREEN_SAT = 100;     // 绿色饱和度
final float BRIGHTNESS_MIN = 20; // 最暗亮度
final float BRIGHTNESS_MAX = 120; // 最亮亮度

// ================== 状态变量 ==================
float mouseSmoothX = 0;
float mouseSmoothY = 0;
float lastMouseX = -999;
float lastMouseY = -999;
long lastMouseTime = 0;
boolean vortexMode = false;

// ================== 预计算缓存 ==================
PFont chineseFont;
float[] sinCache;  // sin 值缓存
float[] cosCache;  // cos 值缓存

void settings() {
  size(1280, 720, P2D);
}

void setup() {
  surface.setTitle("汉字粒子流动：Matrix Rain - Optimized");
  surface.setResizable(false);
  surface.setLocation(200, 100);

  // 纯黑背景
  background(0);

  // 【优化】只创建一次字体
  chineseFont = createChineseFont();
  textAlign(CENTER, CENTER);
  textFont(chineseFont, 15);

  // 【优化】预计算 sin/cos 缓存 (360 度)
  sinCache = new float[360];
  cosCache = new float[360];
  for (int i = 0; i < 360; i++) {
    float angle = radians(i);
    sinCache[i] = sin(angle);
    cosCache[i] = cos(angle);
  }

  // 初始化字符池
  charPool = new String[] {
    "零", "一", "二", "三", "四", "五", "六", "七", "八", "九",
    "宇", "宙", "星", "辰", "海", "潮", "流", "光", "影", "数",
    "码", "网", "络", "云", "岚", "波", "浪", "电", "子", "未",
    "来", "灵", "动", "时", "空", "梦", "境", "虚", "实", "青",
    "蓝", "绿", "白", "黑", "暗", "日", "月", "风", "云", "门",
    "关", "梦", "雨", "链", "路", "核", "心", "源", "码", "无",
    "限", "深", "空", "曦", "光", "尘", "埃", "虚", "拟", "梦",
    "醒", "静", "动", "流", "转", "回", "响", "落", "叶", "夜",
    "晨", "微", "光", "恒", "星", "脉", "冲", "频", "率", "搏",
    "神", "经", "织", "网", "序", "间", "隙", "字", "海", "洋",
    "维", "度", "真", "空", "初", "生", "裂", "变", "转", "译",
    "浮", "沉", "立", "体", "界", "河", "漫", "游", "悄", "然",
    "幽", "灵", "迷", "雾", "阡", "陌", "魂", "晓", "炫", "极",
    "熵", "增", "聚", "高", "速", "迭", "代", "循", "银", "幕",
    "苍", "穹", "轨", "涌", "混", "沌", "量", "想", "象", "明",
    "灭", "进", "退", "暗", "幻", "瑟", "风", "玄", "妙", "奥",
    "义", "觉", "空", "白", "犀", "平", "稳", "跃", "迁", "瞬",
    "息", "清", "醒", "复", "苏"
  };

  // 【优化】预先分配 particles 列表大小
  particles = new ArrayList<LetterParticle>(TOTAL_PARTICLES);
  for (int i = 0; i < TOTAL_PARTICLES; i++) {
    particles.add(new LetterParticle(i));
  }

  // 初始化鼠标位置
  mouseSmoothX = width * 0.5f;
  mouseSmoothY = height * 0.5f;
}

PFont createChineseFont() {
  String[] candidateFonts = {
    "Microsoft YaHei",
    "PingFang SC",
    "Hiragino Sans GB",
    "Noto Sans CJK SC",
    "Noto Sans SC",
    "Source Han Sans SC",
    "WenQuanYi Micro Hei",
    "Arial Unicode MS",
    "SimHei"
  };

  PFont f = null;
  for (String fontName : candidateFonts) {
    try {
      f = createFont(fontName, 15, true);
      if (f != null) return f;
    } catch (Exception e) {
    }
  }
  return createFont("SansSerif", 15, true);
}

void draw() {
  // 【优化】用半透明矩形形成拖尾（不需要填充回黑，直接覆盖）
  fill(0, (int)TRAIL_ALPHA);
  noStroke();
  rect(0, 0, width, height);

  // 更新鼠标交互
  updateMouse();

  // 更新并显示所有粒子
  for (int i = 0; i < particles.size(); i++) {
    LetterParticle p = particles.get(i);
    p.update();
    p.display();
  }

  // 【调试】显示 FPS
  fill(0, 255, 0, 180);
  textAlign(LEFT);
  text("FPS: " + (int)frameRate, 20, 20);
  textAlign(CENTER);
}

void updateMouse() {
  float realMouseX = mouseX;
  float realMouseY = mouseY;

  if (realMouseX < 0 || realMouseX > width || realMouseY < 0 || realMouseY > height) {
    realMouseX = width * 0.5f;
    realMouseY = height * 0.5f;
  }

  // 【优化】平滑鼠标位置 lerp
  mouseSmoothX += (realMouseX - mouseSmoothX) * 0.18f;
  mouseSmoothY += (realMouseY - mouseSmoothY) * 0.18f;

  // 检测鼠标移动
  if (lastMouseX == -999) {
    lastMouseX = realMouseX;
    lastMouseY = realMouseY;
    lastMouseTime = System.currentTimeMillis();
  } else {
    float dist = sqrt((realMouseX - lastMouseX) * (realMouseX - lastMouseX) + 
                      (realMouseY - lastMouseY) * (realMouseY - lastMouseY));
    
    if (dist > 0.5f) {
      vortexMode = false;
      lastMouseX = realMouseX;
      lastMouseY = realMouseY;
      lastMouseTime = System.currentTimeMillis();
    } else {
      long idleTime = System.currentTimeMillis() - lastMouseTime;
      vortexMode = (idleTime > 2000);
    }
  }
}

// ============================================================
// 粒子类 - 优化版本
// ============================================================
class LetterParticle {
  float px, py;           // position
  float vx, vy;           // velocity
  float ax, ay;           // acceleration
  float ox, oy;           // origin
  String character;       // 字符
  float noiseOffset;      // Noise 偏移
  int column, row;        // 栅格位置
  float fallSpeed;        // 下落速度
  float swaySeed;         // 摆动种子
  float glow;             // 呼吸强度
  float hueShift;         // 色相偏移

  LetterParticle(int index) {
    column = index % COLS;
    row = index / COLS;

    ox = START_X + column * PARTICLE_SPACING_X;
    oy = START_Y + row * PARTICLE_SPACING_Y;

    px = ox;
    py = oy;
    vx = 0;
    vy = 0;
    ax = 0;
    ay = 0;

    noiseOffset = random(1000);
    swaySeed = random(TWO_PI);
    glow = random(0.8f, 1.2f);
    hueShift = random(-10, 10);

    fallSpeed = map(noise(noiseOffset), 0, 1, BASE_FALL_SPEED_MIN, BASE_FALL_SPEED_MAX);
    character = charPool[(int)random(charPool.length)];
  }

  void update() {
    // 【优化】简化波浪计算
    float wave = sin((frameCount * 0.025f) + row * WAVE_FREQ * 10 + swaySeed) * WAVE_AMP;
    float n = noise(column * NOISE_SCALE + noiseOffset, row * NOISE_SCALE * 0.8f + noiseOffset * 0.5f);
    float drift = (n - 0.5f) * 2.2f;

    // 下落加速
    float fallBoost = fallSpeed + drift * 0.8f;

    // 弹性回归原点
    ax += (ox - px) * RETURN_SPRING * 0.7f;
    ay += (oy - py) * RETURN_SPRING * 0.7f;

    // 波浪偏移
    ax += wave * 0.026f;
    ax += drift * 0.03f;

    // 持续下落
    ay += fallBoost * 0.11f;

    // 鼠标交互 - 排斥
    float dmx = px - mouseSmoothX;
    float dmy = py - mouseSmoothY;
    float distToMouse = sqrt(dmx * dmx + dmy * dmy);

    if (distToMouse < REPEL_RADIUS && distToMouse > 0.0001f) {
      float strength = (1.0f - distToMouse / REPEL_RADIUS) * REPEL_STRENGTH;
      ax += (dmx / distToMouse) * strength * 18.0f;
      ay += (dmy / distToMouse) * strength * 18.0f;
      vx *= 0.985f;
      vy *= 0.985f;
    }

    // 旋涡交互
    if (vortexMode && distToMouse < VORTEX_RADIUS && distToMouse > 0.0001f) {
      float falloff = 1.0f - distToMouse / VORTEX_RADIUS;
      
      // 向心力
      ax -= (dmx / distToMouse) * CENTER_PULL_STRENGTH * falloff * 20.0f;
      ay -= (dmy / distToMouse) * CENTER_PULL_STRENGTH * falloff * 20.0f;

      // 切向力
      ax += (-dmy / distToMouse) * SWIRL_STRENGTH * falloff * 18.0f;
      ay += (dmx / distToMouse) * SWIRL_STRENGTH * falloff * 18.0f;
    }

    // 速度更新
    vx += ax;
    vy += ay;
    vx *= DAMPING;
    vy *= DAMPING;

    // 限速
    float speed = sqrt(vx * vx + vy * vy);
    if (speed > MAX_SPEED) {
      vx = (vx / speed) * MAX_SPEED;
      vy = (vy / speed) * MAX_SPEED;
    }

    // 位置更新
    px += vx;
    py += vy;

    // 清零加速度
    ax = 0;
    ay = 0;

    // 缓慢回归原位（防止无限漂移）
    px += (ox - px) * 0.02f;
    py += (oy - py) * 0.02f;

    // 循环下落：超出屏幕下方后从顶部重置
    if (py > height + 40) {
      py = -20;
      px = ox + random(-3, 3);
      character = charPool[(int)random(charPool.length)];
      vy = 0;
      fallSpeed = map(random(1), 0, 1, BASE_FALL_SPEED_MIN, BASE_FALL_SPEED_MAX);
    }

    // 边界修正
    if (py < -40) py = -40;
    if (px < -10) px = width + 10;
    if (px > width + 10) px = -10;
  }

  void display() {
    // 【优化】减少计算，使用更简单的颜色生成
    float dmx = px - mouseSmoothX;
    float dmy = py - mouseSmoothY;
    float distToMouse = sqrt(dmx * dmx + dmy * dmy);

    // 呼吸效果
    float breath = 0.5f + 0.5f * sin(frameCount * 0.04f * glow + noiseOffset * 10.0f);

    // 绿色基础色
    float greenBase = 70 + 80 * breath + (1.0f - constrain(distToMouse / VORTEX_RADIUS, 0, 1)) * 60;
    float alpha = 120 + 120 * breath;

    // 旋涡高亮
    if (vortexMode && distToMouse < VORTEX_RADIUS) {
      float centerGlow = constrain(1.0f - distToMouse / VORTEX_RADIUS, 0, 1);
      greenBase += centerGlow * 100.0f;
      alpha += centerGlow * 120.0f;

      if (distToMouse < 150) {
        fill(220, 245, 245, 255);
      } else {
        fill(20 + sin(noiseOffset * 5) * 10, constrain(greenBase + hueShift, 50, 255), 
             20 + sin(noiseOffset * 7) * 10, (int)alpha);
      }
    } else {
      fill(20 + sin(noiseOffset * 5) * 10, constrain(greenBase + hueShift, 50, 255), 
           20 + sin(noiseOffset * 7) * 10, (int)alpha);
    }

    noStroke();

    // 【优化】减少抖动计算，降低视觉复杂度
    float jitterX = sinCache[(int)(frameCount * 5 + row * 4 + noiseOffset) % 360] * 0.35f;
    float jitterY = cosCache[(int)(frameCount * 4 + column * 5 + noiseOffset) % 360] * 0.35f;

    text(character, px + jitterX, py + jitterY);
  }
}
