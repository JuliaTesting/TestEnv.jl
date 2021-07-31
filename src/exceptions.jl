struct TestEnvError <: Exception
    msg::AbstractString
end

function Base.showerror(io::IO, ex::TestEnvError, bt; backtrace=true)
    printstyled(io, ex.msg, color=Base.error_color())
end