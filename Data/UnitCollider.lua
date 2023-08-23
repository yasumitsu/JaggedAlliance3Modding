-- ========== GENERATED BY UnitCollider Editor DO NOT EDIT MANUALLY! ==========

PlaceObj('UnitCollider', {
	BodyParts = {
		PlaceObj('UnitBodyPartCollider', {
			'id', "Head",
			'TargetSpots', {
				"Head",
				"Head2",
			},
			'Colliders', {
				PlaceObj('UnitColliderCapsule', {
					'TargetSpot', "Head",
					'Spot1', "Head",
					'Spot2', "Head2",
					'Radius', 200,
				}),
			},
		}),
		PlaceObj('UnitBodyPartCollider', {
			'id', "Torso",
			'TargetSpots', {
				"Torso",
				"Groin",
				"Tail",
				"Tail2",
			},
			'Colliders', {
				PlaceObj('UnitColliderCapsule', {
					'TargetSpot', "Torso",
					'Spot1', "Shoulderl",
					'Spot2', "Shoulderr",
					'Radius', 200,
				}),
				PlaceObj('UnitColliderCapsule', {
					'TargetSpot', "Torso",
					'Spot1', "Ribsupperl",
					'Spot2', "Ribsupperr",
					'Radius', 200,
				}),
				PlaceObj('UnitColliderCapsule', {
					'TargetSpot', "Torso",
					'Spot1', "Ribslowerl",
					'Spot2', "Ribslowerr",
					'Radius', 200,
				}),
				PlaceObj('UnitColliderCapsule', {
					'TargetSpot', "Torso",
					'Spot1', "Pelvisl",
					'Spot2', "Pelvisr",
					'Radius', 200,
				}),
				PlaceObj('UnitColliderCapsule', {
					'TargetSpot', "Torso",
					'Spot1', "Tail",
					'Spot2', "Tail2",
					'Radius', 150,
				}),
				PlaceObj('UnitColliderCapsule', {
					'TargetSpot', "Torso",
					'Spot1', "Tail2",
					'Spot2', "Tail3",
					'Radius', 100,
				}),
			},
		}),
		PlaceObj('UnitBodyPartCollider', {
			'id', "Legs",
			'TargetSpots', {
				"Elbowl",
				"Elbowr",
				"Kneel",
				"Kneer",
			},
			'Colliders', {
				PlaceObj('UnitColliderCapsule', {
					'TargetSpot', "Elbowl",
					'Spot1', "Elbowl",
					'Spot2', "Shoulderl",
					'Radius', 100,
				}),
				PlaceObj('UnitColliderCapsule', {
					'TargetSpot', "Elbowr",
					'Spot1', "Elbowr",
					'Spot2', "Shoulderr",
					'Radius', 100,
				}),
				PlaceObj('UnitColliderCapsule', {
					'TargetSpot', "Elbowl",
					'Spot1', "Wristl",
					'Spot2', "Elbowl",
					'Radius', 100,
				}),
				PlaceObj('UnitColliderCapsule', {
					'TargetSpot', "Elbowr",
					'Spot1', "Wristr",
					'Spot2', "Elbowr",
					'Radius', 100,
				}),
				PlaceObj('UnitColliderCapsule', {
					'TargetSpot', "Kneel",
					'Spot1', "Kneel",
					'Spot2', "Pelvisl",
					'Radius', 100,
				}),
				PlaceObj('UnitColliderCapsule', {
					'TargetSpot', "Kneer",
					'Spot1', "Kneer",
					'Spot2', "Pelvisr",
					'Radius', 100,
				}),
				PlaceObj('UnitColliderCapsule', {
					'TargetSpot', "Kneel",
					'Spot1', "Anklel",
					'Spot2', "Kneel",
					'Radius', 100,
				}),
				PlaceObj('UnitColliderCapsule', {
					'TargetSpot', "Kneer",
					'Spot1', "Ankler",
					'Spot2', "Kneer",
					'Radius', 100,
				}),
			},
		}),
	},
	group = "Default",
	id = "Crocodile",
})

PlaceObj('UnitCollider', {
	BodyParts = {
		PlaceObj('UnitBodyPartCollider', {
			'id', "Torso",
			'TargetSpots', {
				"Torso",
			},
			'Colliders', {
				PlaceObj('UnitColliderSphere', {
					'TargetSpot', "Torso",
					'Spot', "Torso",
					'Radius', 250,
				}),
			},
		}),
	},
	group = "Default",
	id = "Hen",
})

PlaceObj('UnitCollider', {
	BodyParts = {
		PlaceObj('UnitBodyPartCollider', {
			'id', "Head",
			'TargetSpots', {
				"Head",
			},
			'Colliders', {
				PlaceObj('UnitColliderSphere', {
					'TargetSpot', "Head",
					'Spot', "Head",
					'Radius', 100,
				}),
				PlaceObj('UnitColliderSphere', {
					'TargetSpot', "Head",
					'Spot', "Neck",
					'Radius', 100,
				}),
			},
		}),
		PlaceObj('UnitBodyPartCollider', {
			'id', "Arms",
			'TargetSpots', {
				"Elbowl",
				"Elbowr",
			},
			'Colliders', {
				PlaceObj('UnitColliderCapsule', {
					'TargetSpot', "Elbowl",
					'Spot1', "Elbowl",
					'Spot2', "Shoulderl",
					'Radius', 70,
				}),
				PlaceObj('UnitColliderCapsule', {
					'TargetSpot', "Elbowr",
					'Spot1', "Elbowr",
					'Spot2', "Shoulderr",
					'Radius', 70,
				}),
				PlaceObj('UnitColliderCapsule', {
					'TargetSpot', "Elbowl",
					'Spot1', "Wristl",
					'Spot2', "Elbowl",
					'Radius', 50,
				}),
				PlaceObj('UnitColliderCapsule', {
					'TargetSpot', "Elbowr",
					'Spot1', "Wristr",
					'Spot2', "Elbowr",
					'Radius', 50,
				}),
			},
		}),
		PlaceObj('UnitBodyPartCollider', {
			'id', "Torso",
			'TargetSpots', {
				"Torso",
			},
			'Colliders', {
				PlaceObj('UnitColliderCapsule', {
					'TargetSpot', "Torso",
					'Spot1', "Shoulderl",
					'Spot2', "Shoulderr",
					'Radius', 100,
				}),
				PlaceObj('UnitColliderCapsule', {
					'TargetSpot', "Torso",
					'Spot1', "Ribsupperl",
					'Spot2', "Ribsupperr",
					'Radius', 130,
				}),
				PlaceObj('UnitColliderCapsule', {
					'TargetSpot', "Torso",
					'Spot1', "Ribslowerl",
					'Spot2', "Ribslowerr",
					'Radius', 130,
				}),
				PlaceObj('UnitColliderCapsule', {
					'TargetSpot', "Torso",
					'Spot1', "Pelvisl",
					'Spot2', "Pelvisr",
					'Radius', 130,
				}),
			},
		}),
		PlaceObj('UnitBodyPartCollider', {
			'id', "Groin",
			'TargetSpots', {
				"Groin",
			},
			'Colliders', {
				PlaceObj('UnitColliderSphere', {
					'TargetSpot', "Groin",
					'Spot', "Groin",
					'Radius', 100,
				}),
			},
		}),
		PlaceObj('UnitBodyPartCollider', {
			'id', "Legs",
			'TargetSpots', {
				"Kneel",
				"Kneer",
			},
			'Colliders', {
				PlaceObj('UnitColliderCapsule', {
					'TargetSpot', "Kneel",
					'Spot1', "Kneel",
					'Spot2', "Pelvisl",
					'Radius', 100,
				}),
				PlaceObj('UnitColliderCapsule', {
					'TargetSpot', "Kneer",
					'Spot1', "Kneer",
					'Spot2', "Pelvisr",
					'Radius', 100,
				}),
				PlaceObj('UnitColliderCapsule', {
					'TargetSpot', "Kneel",
					'Spot1', "Anklel",
					'Spot2', "Kneel",
					'Radius', 100,
				}),
				PlaceObj('UnitColliderCapsule', {
					'TargetSpot', "Kneer",
					'Spot1', "Ankler",
					'Spot2', "Kneer",
					'Radius', 100,
				}),
			},
		}),
	},
	group = "Default",
	id = "Human",
})

PlaceObj('UnitCollider', {
	BodyParts = {
		PlaceObj('UnitBodyPartCollider', {
			'id', "Head",
			'TargetSpots', {
				"Head",
				"Head2",
			},
			'Colliders', {
				PlaceObj('UnitColliderCapsule', {
					'TargetSpot', "Head",
					'Spot1', "Head",
					'Spot2', "Head2",
					'Radius', 100,
				}),
				PlaceObj('UnitColliderSphere', {
					'TargetSpot', "Head",
					'Spot', "Neck",
					'Radius', 80,
				}),
			},
		}),
		PlaceObj('UnitBodyPartCollider', {
			'id', "Torso",
			'TargetSpots', {
				"Torso",
				"Groin",
			},
			'Colliders', {
				PlaceObj('UnitColliderCapsule', {
					'TargetSpot', "Torso",
					'Spot1', "Groin",
					'Spot2', "Torso",
					'Radius', 100,
				}),
				PlaceObj('UnitColliderCapsule', {
					'TargetSpot', "Torso",
					'Spot1', "Shoulderl",
					'Spot2', "Shoulderr",
					'Radius', 50,
				}),
			},
		}),
		PlaceObj('UnitBodyPartCollider', {
			'id', "Legs",
			'TargetSpots', {
				"Elbowl",
				"Elbowr",
				"Kneel",
				"Kneer",
			},
			'Colliders', {
				PlaceObj('UnitColliderCapsule', {
					'TargetSpot', "Elbowl",
					'Spot1', "Elbowl",
					'Spot2', "Shoulderl",
					'Radius', 50,
				}),
				PlaceObj('UnitColliderCapsule', {
					'TargetSpot', "Elbowr",
					'Spot1', "Elbowr",
					'Spot2', "Shoulderr",
					'Radius', 50,
				}),
				PlaceObj('UnitColliderCapsule', {
					'TargetSpot', "Elbowl",
					'Spot1', "Wristl",
					'Spot2', "Elbowl",
					'Radius', 50,
				}),
				PlaceObj('UnitColliderCapsule', {
					'TargetSpot', "Elbowr",
					'Spot1', "Wristr",
					'Spot2', "Elbowr",
					'Radius', 50,
				}),
				PlaceObj('UnitColliderCapsule', {
					'TargetSpot', "Kneel",
					'Spot1', "Kneel",
					'Spot2', "Pelvisl",
					'Radius', 50,
				}),
				PlaceObj('UnitColliderCapsule', {
					'TargetSpot', "Kneer",
					'Spot1', "Kneer",
					'Spot2', "Pelvisr",
					'Radius', 50,
				}),
				PlaceObj('UnitColliderCapsule', {
					'TargetSpot', "Kneel",
					'Spot1', "Anklel",
					'Spot2', "Kneel",
					'Radius', 50,
				}),
				PlaceObj('UnitColliderCapsule', {
					'TargetSpot', "Kneer",
					'Spot1', "Ankler",
					'Spot2', "Kneer",
					'Radius', 50,
				}),
			},
		}),
	},
	group = "Default",
	id = "Hyena",
})

