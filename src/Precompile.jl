@setup_workload begin
    leaf = Taproot(2)
    branch = Taproot(3, [Taproot(4), Taproot(5)])
    root = Taproot(1, [branch, leaf])

    @compile_workload begin
        isleaf(leaf)
        isbranch(branch)
        isparent(root, branch)
        ischild(branch, root)

        collect(preorder(root; pathset = AllPaths))
        collect(postorder(root; pathset = NoCycles))
        collect(topdown(root; pathset = OncePerEdge))
        collect(bottomup(root; pathset = OncePerNode))
    end
end
