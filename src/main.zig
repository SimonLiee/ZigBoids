const rl = @import("raylib");
const std = @import("std");
const builtin = @import("builtin");
const gui = @import("gui.zig");
const c = if (builtin.os.tag == .emscripten) @cImport({
    @cInclude("emscripten/emscripten.h");
});

const print = std.debug.print;

const Entity = union(enum) {
    boid: Boid,
    zoid: Zoid,

    fn update(self: *Entity, delta: f32) void {
        switch (self.*) {
            inline else => |*case| return case.update(delta),
        }
    }

    fn draw(self: *Entity) void {
        switch (self.*) {
            inline else => |*case| return case.draw(),
        }
    }
};

const Zoid = struct {
    pos: rl.Vector2,
    dir: rl.Vector2,
    speed: f32,
    width: f32,
    length: f32,

    fn createRandom() Zoid {
        return Zoid{
            .pos = rl.Vector2.init(@floatFromInt(rl.getRandomValue(0, rl.getScreenWidth())), @floatFromInt(rl.getRandomValue(
                0,
                rl.getScreenHeight(),
            ))),
            .dir = rl.Vector2.init(
                @floatFromInt(rl.getRandomValue(-100, 100)),
                @floatFromInt(rl.getRandomValue(-100, 100)),
            ).normalize(),
            .speed = 140,
            .width = 20,
            .length = 25,
        };
    }

    fn update(self: *Zoid, delta: f32) void {
        const closest = self.findClosest();
        self.follow(closest.?.pos, delta);
        self.eat(closest.?);

        self.move(delta);
    }

    fn eat(self: *Zoid, boid: *Boid) void {
        if (self.pos.distance(boid.pos) < self.length) {
            boid.dead = true;
        }
    }

    fn findClosest(self: *Zoid) ?*Boid {
        var closest: ?*Boid = null;
        for (boids.items) |*entity| {
            const boid: *Boid = switch (entity.*) {
                .boid => |*b| b, // Extract Boid
                else => continue, // Skip non-boid entities
            };

            if (closest == null) {
                closest = boid;
            } else if (self.pos.distance(closest.?.pos) > self.pos.distance(boid.pos)) {
                closest = boid;
            }
        }
        return closest;
    }

    fn follow(self: *Zoid, pos: rl.Vector2, delta: f32) void {
        const rotSpeed = 3;
        self.dir = self.dir.rotate(self.dir.angle(pos.subtract(self.pos)) * rotSpeed * delta);
    }

    fn draw(self: *Zoid) void {
        const base = rl.Vector2.init(0, -1);
        const rotation = base.angle(self.dir);
        rl.drawTriangle(
            self.pos.add(rl.Vector2.init(0, -(self.length / 2)).rotate(rotation)),
            self.pos.add(rl.Vector2.init(-(self.width / 2), self.length / 2).rotate(rotation)),
            self.pos.add(rl.Vector2.init(self.width / 2, self.length / 2).rotate(rotation)),
            rl.Color.red,
        );
    }

    fn move(self: *Zoid, delta: f32) void {
        self.pos = self.pos.add(self.dir.normalize().scale(self.speed * delta));
    }
};

const Boid = struct {
    pos: rl.Vector2,
    dir: rl.Vector2,
    speed: f32,
    rotation: f32,
    visionLength: f32,
    width: f32,
    length: f32,
    dead: bool,

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
            .dead = false,
        };
    }

    fn update(self: *Boid, delta: f32) void {
        if (gui.options.bounds) self.bounds(delta);
        if (gui.options.separation) self.separation(delta);
        if (gui.options.cohesion) self.cohesion(delta);
        if (gui.options.alignment) self.alignment(delta);
        self.avoidZoid(delta);

        self.move(delta);
    }

    fn avoidZoid(self: *Boid, delta: f32) void {
        for (boids.items) |*entity| {
            const zoid: *Zoid = switch (entity.*) {
                .zoid => |*z| z, // Extract Zoid
                else => continue, // Skip non-zoid entities
            };
            const distance = self.pos.distance(zoid.pos);
            if (distance > self.visionLength) continue;
            const rotSpeed = 3;
            self.dir = self.dir.rotate(self.dir.angle(self.pos.subtract(zoid.pos)) * rotSpeed * delta);
        }
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

    fn separation(self: *Boid, delta: f32) void {
        const separationForce = 100;
        const separationVision = 35;
        for (boids.items) |*entity| {
            const boid: *Boid = switch (entity.*) {
                .boid => |*b| b, // Extract Boid
                else => continue, // Skip non-boid entities
            };
            if (boid == self) continue;
            const distance = self.pos.distance(boid.pos);
            if (distance > separationVision) continue;

            const diff = self.pos
                .subtract(boid.pos)
                .normalize()
                .scale((separationForce / distance) * delta);
            self.dir = self.dir.add(diff).normalize();
        }
    }

    fn cohesion(self: *Boid, delta: f32) void {
        const cohesionForce = 0.01;
        for (boids.items) |*entity| {
            const boid: *Boid = switch (entity.*) {
                .boid => |*b| b, // Extract Boid
                else => continue, // Skip non-boid entities
            };
            if (self.pos.distance(boid.pos) > self.visionLength) continue;
            self.dir = self.dir.add(boid.pos.subtract(self.pos).normalize().scale(cohesionForce * delta));
        }
    }

    fn alignment(self: *Boid, delta: f32) void {
        const alignmentForce = 0.4;
        var avgDir = rl.Vector2.zero();
        var total: i32 = 0;

        for (boids.items) |*entity| {
            const boid: *Boid = switch (entity.*) {
                .boid => |*b| b, // Extract Boid
                else => continue, // Skip non-boid entities
            };
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
var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
var boids: std.ArrayList(Entity) = undefined;

//------------------------------------------------------------------------------------
// Program main entry point
//------------------------------------------------------------------------------------
pub fn main() anyerror!void {
    boids = std.ArrayList(Entity).init(gpa.allocator());

    const seed: u32 = @truncate(@as(u128, @intCast(std.time.nanoTimestamp())));
    rl.setRandomSeed(seed);

    // Initialization
    //--------------------------------------------------------------------------------------
    rl.initWindow(800, 800, "raylib-zig [core] example - basic window");
    defer rl.closeWindow(); // Close window and OpenGL context

    for (0..10) |_| {
        try boids.append(Entity{ .boid = Boid.createRandom() });
    }

    for (0..1) |_| {
        try boids.append(Entity{ .zoid = Zoid.createRandom() });
    }

    rl.setWindowState(rl.ConfigFlags{ .window_resizable = true });

    if (builtin.os.tag == .emscripten) {
        c.emscripten_set_main_loop(@ptrCast(&updateDrawFrame), 0, true);
    } else {
        //rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second

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
    gui.mainMenu.update();

    for (boids.items) |*entity| {
        entity.update(delta);
    }

    // Remove dead
    var i: usize = 0;
    while (i < boids.items.len) {
        const boid: *Boid = switch (boids.items[i]) {
            .boid => |*b| b, // Extract Boid
            else => { // Skip non-boid entities
                i += 1;
                continue;
            },
        };

        if (boid.dead) {
            if (gui.options.respawn) {
                boid.* = Boid.createRandom();
            } else {
                _ = boids.swapRemove(i);
                continue;
            }
        }
        i += 1;
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

    rl.clearBackground(rl.Color.dark_purple);

    camera.begin();
    rl.drawRectangleLinesEx(
        rl.Rectangle.init(
            0,
            0,
            @floatFromInt(rl.getScreenWidth()),
            @floatFromInt(rl.getScreenHeight()),
        ),
        1,
        rl.Color.black,
    );
    for (boids.items) |*boid| {
        boid.draw();
    }
    camera.end();

    rl.drawFPS(10, 10);
    gui.mainMenu.draw();
    //----------------------------------------------------------------------------------
}
