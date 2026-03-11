// Snack bag clip — parametric
// A simple spring-action clip for sealing bags
//
// Parameters:
count = 4;          // number of clips to print
clip_length = 80;   // mm — how wide of a bag it can grip
clip_width = 12;    // mm
wall = 2.0;         // mm — wall thickness
gap = 1.5;          // mm — opening gap
hinge_r = 4;        // mm — hinge radius
grip_teeth = 8;     // number of grip teeth per jaw

module single_clip() {
    // Upper jaw
    translate([0, 0, gap/2])
        jaw();

    // Lower jaw (mirrored)
    mirror([0, 0, 1])
        translate([0, 0, gap/2])
            jaw();

    // Living hinge at the back
    translate([-clip_length/2, 0, 0])
        hinge();
}

module jaw() {
    difference() {
        union() {
            // Main jaw body
            translate([0, 0, 0])
                cube([clip_length, clip_width, wall], center=true);

            // Grip handle (rear extension)
            translate([-clip_length/2 - 8, 0, wall/2])
                cube([16, clip_width, wall], center=true);
        }

        // Grip teeth cutouts on the inside face
        for (i = [0:grip_teeth-1]) {
            translate([
                -clip_length/2 + clip_length/(grip_teeth+1) * (i+1),
                0,
                -wall/2
            ])
                cube([1.5, clip_width + 1, 0.8], center=true);
        }
    }
}

module hinge() {
    // Living hinge — a thin curved section connecting upper and lower jaws
    difference() {
        cylinder(h=clip_width, r=hinge_r, center=true, $fn=40);
        cylinder(h=clip_width + 1, r=hinge_r - wall*0.6, center=true, $fn=40);
        // Cut away front half to create the U-shape hinge
        translate([hinge_r/2, 0, 0])
            cube([hinge_r, hinge_r*2 + 1, clip_width + 1], center=true);
    }
}

// Arrange clips in a grid
spacing = clip_width + 5;
for (i = [0:count-1]) {
    translate([0, i * spacing, 0])
        single_clip();
}
