// A raylib-zig port of https://github.com/raysan5/raylib/blob/master/examples/core/core_basic_window_web.c

const rl = @import("raylib");
const std = @import("std");
const builtin = @import("builtin");
const c = if (builtin.os.tag == .emscripten) @cImport({
    @cInclude("emscripten/emscripten.h");
});

const print = std.debug.print;

const Boid = struct {
    pos: rl.Vector2,
    dir: rl.Vector2,
    speed: f32,
    rotation: f32,
    visionLength: f32,
    width: f32,
    length: f32,

    fn createRandom() Boid {
        return Boid{
            .pos = rl.Vector2.init(@floatFromInt(rl.getRandomValue(0, rl.getScreenWidth())), @floatFromInt(rl.getRandomValue(
                0,
                rl.getScreenHeight(),
            ))),
            .dir = rl.Vector2.init(
                @floatFromInt(rl.getRandomValue(-100, 100)),
                @floatFromInt(rl.getRandomValue(-100, 100)),
            ).normalize(),
            .rotation = @as(f32, @floatFromInt(rl.getRandomValue(0, 100))) * 0.01,
            .speed = 120, // @as(f32, @floatFromInt(rl.getRandomValue(10, 50))),
            .visionLength = 200,
            .width = 15,
            .length = 18,
        };
    }

    fn update(self: *Boid, delta: f32) void {
        self.bounds(delta);
        self.seperation(delta);
        self.cohesion(delta);
        self.alignment(delta);

        self.move(delta);
    }

    fn move(self: *Boid, delta: f32) void {
        self.pos = self.pos.add(self.dir.normalize().scale(self.speed * delta));
    }

    fn bounds(self: *Boid, delta: f32) void {
        const boundsForce = 1.5;
        const visionAngle = 0.9;
        const screenWidth = @as(f32, @floatFromInt(rl.getScreenWidth()));
        const screenHeight = @as(f32, @floatFromInt(rl.getScreenHeight()));

        const leftVisionPos = self.pos.add(self.dir.scale(self.visionLength).rotate(visionAngle));
        const rightVisionPos = self.pos.add(self.dir.scale(self.visionLength).rotate(-visionAngle));

        if (leftVisionPos.x < 0 or rightVisionPos.x < 0) {
            self.rotateBoid(1, 0, delta * boundsForce); // Rotate to right dir
        } else if (leftVisionPos.x > screenWidth or rightVisionPos.x > screenWidth) {
            self.rotateBoid(-1, 0, delta * boundsForce); // Rotate to left dir
        } else if (leftVisionPos.y < 0 or rightVisionPos.y < 0) {
            self.rotateBoid(0, 1, delta * boundsForce); // Rotate to down dir
        } else if (leftVisionPos.y > screenHeight or rightVisionPos.y > screenHeight) {
            self.rotateBoid(0, -1, delta * boundsForce); // Rotate to up dir
        }
    }

    fn seperation(self: *Boid, delta: f32) void {
        const seperationForce = 100;
        const seperationVision = 35;
        for (boids.items) |*boid| {
            if (boid == self) continue;
            const distance = self.pos.distance(boid.pos);
            if (distance > seperationVision) continue;

            const diff = self.pos
                .subtract(boid.pos)
                .normalize()
                .scale((seperationForce / distance) * delta);
            self.dir = self.dir.add(diff).normalize();
        }
    }

    fn cohesion(self: *Boid, delta: f32) void {
        const cohesionForce = 0.01;
        for (boids.items) |*boid| {
            if (self.pos.distance(boid.pos) > self.visionLength) continue;
            self.dir = self.dir.add(boid.pos.subtract(self.pos).normalize().scale(cohesionForce * delta));
        }
    }

    fn alignment(self: *Boid, delta: f32) void {
        const alignmentForce = 1.0;
        var avgDir = rl.Vector2.zero();
        var total: i32 = 0;

        for (boids.items) |*boid| {
            if (self.pos.distance(boid.pos) > self.visionLength) continue;
            total += 1;
            avgDir = avgDir.add(boid.dir);
        }
        avgDir = avgDir.divide(rl.Vector2.init(@floatFromInt(total), @floatFromInt(total)));

        const diff = avgDir.subtract(self.dir).normalize();
        self.dir = self.dir.add(diff.scale(alignmentForce * delta));
    }

    fn rotateBoid(self: *Boid, x: f32, y: f32, delta: f32) void {
        const rot = self.dir.angle(rl.Vector2.init(x, y)) * delta;
        self.dir = self.dir.rotate(rot);
    }

    fn draw(self: *Boid) void {
        const base = rl.Vector2.init(0, -1);
        self.rotation = base.angle(self.dir);
        rl.drawTriangle(
            self.pos.add(rl.Vector2.init(0, -(self.length / 2)).rotate(self.rotation)),
            self.pos.add(rl.Vector2.init(-(self.width / 2), self.length / 2).rotate(self.rotation)),
            self.pos.add(rl.Vector2.init(self.width / 2, self.length / 2).rotate(self.rotation)),
            rl.Color.blue,
        );
    }
};

//----------------------------------------------------------------------------------
// Global Variables Definition
//----------------------------------------------------------------------------------
var boids: std.ArrayList(Boid) = undefined;
var gpa = std.heap.GeneralPurposeAllocator(.{}).init;

//------------------------------------------------------------------------------------
// Program main entry point
//------------------------------------------------------------------------------------
pub fn main() anyerror!void {
    boids = std.ArrayList(Boid).init(gpa.allocator());

    const seed: u32 = @truncate(@as(u128, @intCast(std.time.nanoTimestamp())));
    rl.setRandomSeed(seed);

    // Initialization
    //--------------------------------------------------------------------------------------
    rl.initWindow(800, 800, "raylib-zig [core] example - basic window");
    defer rl.closeWindow(); // Close window and OpenGL context

    for (0..300) |_| {
        try boids.append(Boid.createRandom());
    }

    rl.setWindowState(rl.ConfigFlags{ .window_resizable = true });

    if (builtin.os.tag == .emscripten) {
        c.emscripten_set_main_loop(@ptrCast(&updateDrawFrame), 0, true);
    } else {
        rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second

        // Main game loop
        while (!rl.windowShouldClose()) { // Detect window close button or ESC key
            updateDrawFrame();
        }
    }
}

// Update and Draw one frame
fn updateDrawFrame() void {
    const delta = rl.getFrameTime();
    // Update
    //----------------------------------------------------------------------------------
    for (boids.items) |*boid| {
        boid.update(delta);
    }
    //----------------------------------------------------------------------------------

    // Draw
    //----------------------------------------------------------------------------------
    var camera = rl.Camera2D{
        .target = rl.Vector2.init(
            @as(f32, @floatFromInt(rl.getScreenWidth())) / 2,
            @as(f32, @floatFromInt(rl.getScreenHeight())) / 2,
        ),
        .offset = rl.Vector2.init(
            @as(f32, @floatFromInt(rl.getScreenWidth())) / 2,
            @as(f32, @floatFromInt(rl.getScreenHeight())) / 2,
        ),
        .rotation = 0,
        .zoom = 0.9,
    };
    rl.beginDrawing();
    defer rl.endDrawing();

    rl.clearBackground(rl.Color.white);

    camera.begin();
    rl.drawRectangleLinesEx(
        rl.Rectangle.init(
            0,
            0,
            @floatFromInt(rl.getScreenWidth()),
            @floatFromInt(rl.getScreenHeight()),
        ),
        5,
        rl.Color.black,
    );
    for (boids.items) |*boid| {
        boid.draw();
    }
    camera.end();
    //----------------------------------------------------------------------------------
}
