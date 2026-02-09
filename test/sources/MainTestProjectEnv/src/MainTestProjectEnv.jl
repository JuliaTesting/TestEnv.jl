module MainTestProjectEnv
using DependentEnv

bar() = DependentEnv.foo() + 2  # Same as in MainEnv

end
