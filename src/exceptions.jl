abstract type LibPQException <: Exception end

"An exception with an error message generated by PostgreSQL"
abstract type PQException <: LibPQException end

# PostgreSQL errors have trailing newlines
# https://www.postgresql.org/docs/10/libpq-status.html#LIBPQ-PQERRORMESSAGE
Base.showerror(io::IO, err::PQException) = print(io, chomp(err.msg))

"An exception generated by LibPQ.jl"
abstract type JLClientException <: LibPQException end

struct PQConnectionError <: PQException
    msg::String
end

function PQConnectionError(jl_conn::Connection)
    return PQConnectionError(error_message(jl_conn))
end

struct ConninfoParseError <: PQException
    msg::String
end

struct JLConnectionError <: JLClientException
    msg::String
end

struct JLResultError <: JLClientException
    msg::String
end

struct PQResultError{Class, Code} <: LibPQException
    msg::String
    verbose_msg::Union{String, Nothing}

    function PQResultError{Class_, Code_}(msg, verbose_msg) where {Class_, Code_}
        return new{Class_::Class, Code_::ErrorCode}(
            convert(String, msg),
            convert(Union{String, Nothing}, verbose_msg),
        )
    end
end

include("error_codes.jl")

function PQResultError{Class, Code}(msg::String) where {Class, Code}
    return PQResultError{Class, Code}(msg, nothing)
end

function PQResultError(result::Result; verbose=false)
    msg = error_message(result; verbose=false)
    verbose_msg = verbose ? error_message(result; verbose=true) : nothing
    code = error_field(result, libpq_c.PG_DIAG_SQLSTATE)

    return PQResultError{Class(code), ErrorCode(code)}(msg, verbose_msg)
end

error_class(err::PQResultError{Class_}) where {Class_} = Class_::Class
error_code(err::PQResultError{Class_, Code_}) where {Class_, Code_} = Code_::ErrorCode

function showerror(io, err::T) where T <: PQResultError
    msg = err.verbose === nothing ? err.msg : err.verbose_msg

    print(io, ERROR_CODES[T], ": ", msg)
end

function show(io, err::T) where T <: PQResultError
    print(io, ERROR_CODES[T], '(', repr(err.msg))

    if err.verbose_msg !== nothing
        print(io, ", ", repr(err.verbose_msg))
    end

    print(io, ')')
end
