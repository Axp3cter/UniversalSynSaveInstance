--[[
	Attribute Types - Binary Type IDs

	@author Aspecter
	@version 1.0.0
]]

export type AttributeTypes = {
	string: number,
	boolean: number,
	number: number,
	UDim: number,
	UDim2: number,
	Ray: number,
	Faces: number,
	Axes: number,
	BrickColor: number,
	Color3: number,
	Vector2: number,
	Vector3: number,
	Vector2int16: number,
	Vector3int16: number,
	CFrame: number,
	EnumItem: number,
	NumberSequence: number,
	NumberSequenceKeypoint: number,
	ColorSequence: number,
	ColorSequenceKeypoint: number,
	NumberRange: number,
	Rect: number,
	PhysicalProperties: number,
	Region3: number,
	Region3int16: number,
	Font: number,
}

return {
	string = 0x02,
	boolean = 0x03,
	number = 0x06,
	UDim = 0x09,
	UDim2 = 0x0A,
	Ray = 0x0B,
	Faces = 0x0C,
	Axes = 0x0D,
	BrickColor = 0x0E,
	Color3 = 0x0F,
	Vector2 = 0x10,
	Vector3 = 0x11,
	Vector2int16 = 0x12,
	Vector3int16 = 0x13,
	CFrame = 0x14,
	EnumItem = 0x15,
	NumberSequence = 0x17,
	NumberSequenceKeypoint = 0x18,
	ColorSequence = 0x19,
	ColorSequenceKeypoint = 0x1A,
	NumberRange = 0x1B,
	Rect = 0x1C,
	PhysicalProperties = 0x1D,
	Region3 = 0x1F,
	Region3int16 = 0x20,
	Font = 0x21,
} :: AttributeTypes
