using ExplicitImports: test_explicit_imports
using JET: JET

#─────────────────────────────────────────────────────────────────────────────#
# Static analysis
#─────────────────────────────────────────────────────────────────────────────#

@testset "ExplicitImports" begin
    if VERSION >= v"1.11"
        # Base.SizeUnknown and Base.promote_op are the documented ways in to the iteration
        # and inference interfaces, they just aren't marked public
        test_explicit_imports(Taproots; all_qualified_accesses_are_public = (; ignore = (:SizeUnknown, :promote_op)))
    else # no `public` keyword before 1.11, so there is nothing to check publicity against
        test_explicit_imports(Taproots; all_explicit_imports_are_public = false, all_qualified_accesses_are_public = false)
    end
end

# JET's analysis shifts with each Julia release, so only hold the package to it on the current stable release
if VERSION >= v"1.12" && isempty(VERSION.prerelease)
    @testset "JET" begin
        JET.test_package(Taproots; target_modules = (Taproots,))
    end
end
