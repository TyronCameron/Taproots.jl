
#─────────────────────────────────────────────────────────────────────────────#
# Set up structs that players might use
#─────────────────────────────────────────────────────────────────────────────#

struct MyType
	values::Vector
end
Taproots.children(x::MyType) = x.values

mutable struct MoreFlexiTaproot
	data
	children
end
Taproots.children(x::MoreFlexiTaproot) = x.children
Base.show(io::IO, x::MoreFlexiTaproot) = print(io, "MoreFlexiTaproot(", x.data, ")+$(length(x.children)) children")
Taproots.data(x::MoreFlexiTaproot) = x.data
Taproots.setdata!(x::MoreFlexiTaproot, data) = (x.data = data; node)
Taproots.setchildren!(x::MoreFlexiTaproot, children::Vector) = (x.children = children; x)

struct MyLeafType
	x
end

mutable struct BinaryTree
	left
	right
end
Taproots.children(x::BinaryTree) = (x.left, x.right)

#─────────────────────────────────────────────────────────────────────────────#
# Initialise variables
#─────────────────────────────────────────────────────────────────────────────#

expr = :(println("Taproot's favourite number = " * (29 + 13)))

child_dict = Dict(:x => 5, :y => "hello world")
dict = Dict(1 => child_dict, "y" => "dead end")

taproot = Taproot("The Root", [
	Taproot("First branch", [Taproot("Leaf 1", Taproot[])]),
	Taproot(2, [Taproot("Stubby", Taproot[])]),
	Taproot("Leaf at the top", Taproot[]),
])

my_type = MyType(["Something here", "Something else here", MyType([])])

my_complex_type = MyType([
	MoreFlexiTaproot(MyLeafType("Data can be stored here, but we'll iterate past it"), [MyLeafType("This will be iterated")]),
	MyLeafType("A stub"),
])

cycle = BinaryTree(nothing, nothing)
cycle.left = cycle

collider = MoreFlexiTaproot("The top", [
	MoreFlexiTaproot("Go left", ["Collider", "Loner"]),
	MoreFlexiTaproot("Go right", ["Collider"]),
])

deepdag = BinaryTree("The root", nothing)
current = deepdag
for i in 1:20000
	global current.right = BinaryTree(i, nothing)
	global current = current.right
end

final_collider = Taproot("A final collision", Taproot[])
first_collider = Taproot("First collider", [
	Taproot("Go left second", [final_collider]),
	Taproot("Go right second", [final_collider])
])
doubleup = Taproot("Doubleup root", [
	Taproot("Go left first", [first_collider]),
	Taproot("Go right first", [first_collider])
])

different_heights = MoreFlexiTaproot("Top", [
	MoreFlexiTaproot("A", [
		MoreFlexiTaproot("Leaf", MoreFlexiTaproot[])
	]),
	MoreFlexiTaproot("B", MoreFlexiTaproot[])
])

fast_examples = (expr, dict, taproot, my_type, my_complex_type, collider, doubleup, different_heights)