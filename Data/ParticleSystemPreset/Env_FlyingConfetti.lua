-- ========== GENERATED BY ParticleSystemPreset Editor DO NOT EDIT MANUALLY! ==========

PlaceObj('ParticleSystemPreset', {
	game_time_animated = true,
	group = "Environment",
	id = "Env_FlyingConfetti",
	PlaceObj('ParticleEmitter', {
		'label', "Confetti",
		'time_stop', 2000,
		'time_period', 2000,
		'randomize_period', 80,
		'emit_detail_level', 100,
		'max_live_count', 10,
		'parts_per_sec', 100,
		'parts_per_meter', 400,
		'lifetime_min', 2000,
		'lifetime_max', 8000,
		'size_min', 500,
		'size_max', 700,
		'texture', "Textures/Particles/Confetti_2x2.tga",
		'normalmap', "Textures/Particles/Confetti_2x2.norm.tga",
		'frames', point(2, 2),
		'softness', 20,
		'outlines', {
			{
				point(272, 1888),
				point(1056, 1920),
				point(1232, 128),
				point(480, 80),
			},
			{
				point(2096, 1648),
				point(2816, 1968),
				point(3872, 336),
				point(3408, 16),
			},
			{
				point(512, 2992),
				point(736, 3760),
				point(2032, 3344),
				point(1680, 2688),
			},
			{
				point(2352, 3008),
				point(3456, 3424),
				point(3680, 2640),
				point(2528, 2448),
			},
		},
		'texture_hash', -5146419734184302319,
	}, nil, nil),
	PlaceObj('ParticleBehaviorResizeCurve', {
		'max_size', 200,
		'size_curve', {
			range_y = 10,
			scale = 1000,
			point(0, 406, 406),
			point(130, 817, 817),
			point(889, 800, 800),
			point(1000, 263, 263),
		},
	}, nil, nil),
	PlaceObj('ParticleBehaviorRotate', {
		'probability', 60,
		'rpm_curve', {
			range_y = 10,
			scale = 10,
			point(0, 66, 66),
			point(291, 213, 213),
			point(805, 208, 208),
			point(1000, 100, 100),
		},
		'rpm_curve_range', range(-400, 400),
	}, nil, nil),
	PlaceObj('ParticleBehaviorColorize', {
		'start_color_min', RGBA(224, 147, 227, 255),
		'start_intensity_min', 1600,
		'start_color_max', RGBA(244, 112, 109, 255),
		'start_intensity_max', 1600,
		'mid_color', RGBA(114, 174, 242, 255),
		'end_color', RGBA(116, 238, 119, 255),
		'type', "One of four",
	}, nil, nil),
	PlaceObj('ParticleBehaviorRandomSpeedSpray', {
		'spread_angle_min', 3000,
		'spread_angle', 8000,
		'vel_min', 400,
		'vel_max', 600,
	}, nil, nil),
	PlaceObj('ParticleBehaviorFriction', {
		'probability', 20,
		'friction', {
			range_y = 10,
			scale = 1000,
			point(0, 936, 936),
			point(320, 950, 950),
			point(660, 987, 987),
			point(1000, 1056, 1056),
		},
	}, nil, nil),
	PlaceObj('ParticleBehaviorTornado', {
		'direction', point(-1000, 0, 0),
		'start_rpm', 1000,
		'mid_rpm', 1000,
		'end_rpm', 1000,
	}, nil, nil),
	PlaceObj('ParticleBehaviorGravityWind', {
		'probability', 60,
	}, nil, nil),
	PlaceObj('ParticleBehaviorWind', {
		'multiplier', 1200,
	}, nil, nil),
	PlaceObj('ParticleBehaviorPickFrame', nil, nil, nil),
	PlaceObj('DisplacerSphere', {
		'inner_radius', 400,
		'outer_radius', 1000,
	}, nil, nil),
	PlaceObj('DisplacerSurfaceBirth', {
		'time_stop', 200,
	}, nil, nil),
	PlaceObj('FaceAlongMovement', {
		'probability', 60,
	}, nil, nil),
	PlaceObj('ParticleBehaviorFadeInOut', {
		'fade_curve', {
			range_y = 10,
			scale = 1000,
			point(0, 857, 857),
			point(44, 1000, 1000),
			point(928, 1000, 1000),
			point(1000, 0, 0),
		},
	}, nil, nil),
})

