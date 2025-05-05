module MainEnv
using DependentEnv

bar() = DependentEnv.foo() + 2

end
