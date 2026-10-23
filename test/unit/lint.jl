using ExplicitImports: test_explicit_imports
using JET: JET

#─────────────────────────────────────────────────────────────────────────────#
# Static analysis
#─────────────────────────────────────────────────────────────────────────────#

@testset "ExplicitImports" begin
    if VERSION >= v"1.11"
        test_explicit_imports(Taproots; all_qualified_accesses_are_public = (; ignore = (:SizeUnknown, :promote_op)))
    else
        test_explicit_imports(Taproots; all_explicit_imports_are_public = false, all_qualified_accesses_are_public = false)
    end
end

if VERSION >= v"1.12" && isempty(VERSION.prerelease)
    @testset "JET" begin
        JET.test_package(Taproots; target_modules = (Taproots,))
    end
end
