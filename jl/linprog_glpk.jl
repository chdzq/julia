include("linprog_glpk_h.jl")

_jl_glpk = dlopen("libglpk")

macro glpk_ccall(func, args...)
    f = "glp_$(func)"
    quote
        ccall(dlsym(_jl_glpk, $f), $args...)
    end
end

typealias VecOrNothing{T} Union(AbstractVector{T}, AbstractVector{None}, Nothing)
typealias MatOrNothing{T} Union(AbstractMatrix{T}, AbstractVector{None}, Nothing)
_jl_glpk__is_empty{T}(x::Union(VecOrNothing{T}, MatOrNothing{T})) =
        isa(x, Union(AbstractVector{None}, Nothing))

## Wrap GLPK API

type GLPError <: Exception
    msg::String
end

type GLPProb
    p::Ptr{Void}
    function GLPProb()
        p = @glpk_ccall create_prob Ptr{Void} ()
        prob = new(p)
        finalizer(prob, glp_delete_prob)
        return prob
    end
end

_jl_glpk__simplex_param_struct_desc = CStructDescriptor(["glpk.h"], "glp_smcp",
        [("msg_lev", Int32), ("meth", Int32), ("pricing", Int32),
         ("r_test", Int32), ("tol_bnd", Float64), ("tol_dj", Float64),
         ("tol_piv", Float64), ("obj_ll", Float64), ("obj_ul", Float64),
         ("it_lim", Int32), ("tm_lim", Int32), ("out_frq", Int32),
         ("out_dly", Int32), ("presolve", Int32)])

type GLPSimplexParam <: CStructWrapper
    struct::CStruct
    function GLPSimplexParam()
        struct = CStruct(_jl_glpk__simplex_param_struct_desc)
        @glpk_ccall init_smcp Int32 (Ptr{Void},) pointer(struct)
        param = new(struct)
        finalizer(param, cstruct_delete)
        return param
    end
end

_jl_glpk__interior_param_struct_desc = CStructDescriptor(["glpk.h"], "glp_iptcp",
        [("msg_lev", Int32), ("ord_alg", Int32)])

type GLPInteriorParam <: CStructWrapper
    struct::CStruct
    function GLPInteriorParam()
        struct = CStruct(_jl_glpk__interior_param_struct_desc)
        @glpk_ccall init_iptcp Int32 (Ptr{Void},) pointer(struct)
        param = new(struct)
        finalizer(param, cstruct_delete)
        return param
    end
end

_jl_glpk__intopt_param_struct_desc = CStructDescriptor(["glpk.h"], "glp_iocp",
    [("msg_lev", Int32), ("br_tech", Int32), ("bt_tech", Int32),
     ("pp_tech", Int32), ("fp_heur", Int32), ("gmi_cuts", Int32),
     ("mir_cuts", Int32), ("cov_cuts", Int32), ("clq_cuts", Int32),
     ("tol_int", Float64), ("tol_obj", Float64), ("mip_gap", Float64),
     ("tm_lim", Int32), ("out_frq", Int32), ("out_dly", Int32),
     ("cb_func", Ptr{Void}), ("cb_info", Ptr{Void}), ("cb_size", Int32),
     ("presolve", Int32), ("binarize", Int32)])

type GLPIntoptParam <: CStructWrapper
    struct::CStruct
    function GLPIntoptParam()
        struct = CStruct(_jl_glpk__intopt_param_struct_desc)
        @glpk_ccall init_iocp Int32 (Ptr{Void},) pointer(struct)
        param = new(struct)
        finalizer(param, cstruct_delete)
        return param
    end
end

_jl_glpk__basisfact_param_struct_desc = CStructDescriptor(["glpk.h"], "glp_bfcp",
    [("type", Int32), ("lu_size", Int32), ("piv_tol", Float64),
     ("piv_lim", Int32), ("suhl", Int32), ("eps_tol", Float64),
     ("max_gro", Float64), ("nfs_max", Int32), ("upd_tol", Float64),
     ("nrs_max", Int32), ("rs_size", Int32)])

type GLPBasisFactParam <: CStructWrapper
    struct::CStruct
    function GLPBasisFactParam()
        struct = CStruct(_jl_glpk__basisfact_param_struct_desc)
        #@glpk_ccall init_bfcp Int32 (Ptr{Void},) pointer(struct)
        param = new(struct)
        finalizer(param, cstruct_delete)
        return param
    end
end

function glp_delete_prob(glp_prob::GLPProb)
    if glp_prob.p == C_NULL
        return
    end
    @glpk_ccall delete_prob Void (Ptr{Void},) glp_prob.p
    glp_prob.p = C_NULL
    return
end

function _jl_glpk__check_glp_prob(glp_prob::GLPProb)
    if glp_prob.p == C_NULL
        throw(GLPError("Invalid GLPProb"))
    end
    return true
end

function _jl_glpk__check_row_is_valid(glp_prob::GLPProb, row::Int)
    rows = @glpk_ccall get_num_rows Int32 (Ptr{Void},) glp_prob.p
    if (row < 1 || row > rows)
        throw(GLPError("Invalid row $row (must be 1 <= row <= $rows)"))
    end
    return true
end

function _jl_glpk__check_col_is_valid(glp_prob::GLPProb, col::Int)
    cols = @glpk_ccall get_num_cols Int32 (Ptr{Void},) glp_prob.p
    if (col < 1 || col > cols)
        throw(GLPError("Invalid col $col (must be 1 <= col <= $cols)"))
    end
    return true
end

function _jl_glpk__check_col_is_valid_w0(glp_prob::GLPProb, col::Int)
    cols = @glpk_ccall get_num_cols Int32 (Ptr{Void},) glp_prob.p
    if (col < 0 || col > cols)
        throw(GLPError("Invalid col $col (must be 0 <= col <= $cols)"))
    end
    return true
end

function _jl_glpk__check_obj_dir_is_valid(dir::Int32)
    if ~(dir == GLP_MIN || dir == GLP_MAX)
        throw(GLPError("Invalid obj_dir $dir (use GLP_MIN or GLP_MAX)"))
    end
    return true
end

function _jl_glpk__check_bounds_type_is_valid(bounds_type::Int32)
    if ~(bounds_type == GLP_FR ||
         bounds_type == GLP_LO ||
         bounds_type == GLP_UP ||
         bounds_type == GLP_DB ||
         bounds_type == GLP_FX)
        throw(GLPError("Invalid bounds_type $bounds_type (allowed values: GLP_FR, GLP_LO, GLP_UP, GLP_DB, GLP_FX)"))
    end
    return true
end

function _jl_glpk__check_bounds_are_valid(bounds_type::Int32, lb::Real, ub::Real)
    if bounds_type == GLP_DB && lb > ub
        throw(GLPError("Invalid bounds for double-bounded variable: $lb > $ub"))
    elseif bounds_type == GLP_FX && lb != ub
        throw(GLPError("Invalid bounds for fixed variable: $lb != $ub"))
    end
    return true
end

function _jl_glpk__check_vectors_size(numel::Int, vecs...)
    if numel < 0
        throw(GLPError("Invalid numer of elements: $k"))
    end
    if numel > 0
        for v = vecs
            if _jl_glpk__is_empty(v)
                throw(GLPError("Number of elements is $numel but vector is empty or nothing"))
            elseif length(v) < numel
                throw(GLPError("Wrong vector size: $(length(v)) (numel declared as $numel)"))
            end
        end
    end
    return true
end

function _jl_glpk__check_indices_vectors_dup(glp_prob::GLPProb, numel::Int, ia::Vector{Int32}, ja::Vector{Int32})
    rows = @glpk_ccall get_num_rows Int32 (Ptr{Void},) glp_prob.p
    cols = @glpk_ccall get_num_cols Int32 (Ptr{Void},) glp_prob.p
    #numel = length(ia)

    off32 = sizeof(Int32)
    iap = pointer(ia) - off32
    jap = pointer(ja) - off32

    k = @glpk_ccall check_dup Int32 (Int32, Int32, Int32, Ptr{Int32}, Ptr{Int32}) rows cols numel iap jap
    if k < 0
        throw(GLPError("indices out of bounds: $(ia[-k]),$(ja[-k]) (bounds are (1,1) <= (ia,ja) <= ($rows,$cols))"))
    elseif k > 0
        throw(GLPError("duplicate index entry: $(ia[k]),$(ja[k])"))
    end
    return true
end

function _jl_glpk__check_rows_and_cols(rows::Int, cols::Int)
    if (rows < 0)
        throw(GLPError("rows < 0 : $rows"))
    end
    if (cols < 0)
        throw(GLPError("cols < 0 : $rows"))
    end
end

function _jl_glpk__check_rows_ids(glp_prob::GLPProb, min_size::Int, num_rows::Int, rows_ids::Vector{Int32})
    rows = @glpk_ccall get_num_rows Int32 (Ptr{Void},) glp_prob.p
    if num_rows < min_size || num_rows > rows
        throw(GLPError("invalid vector size: $num_rows (min=$min_size max=$rows)"))
    end
    if num_rows == 0
        return true
    end
    if length(row_ids) < num_rows
        throw(GLPError("invalid vector size: declared>=$num_rows actual=$(length(rows_ids))"))
    end
    ind_set = IntSet()
    add_each(ind_set, row_ids[1 : num_rows])
    if min(ind_set) < 1 || max(ind_set) > rows
        throw(GLPError("index out of bounds (min=1 max=$rows)"))
    elseif length(ind_set) != length(row_ids)
        throw(GLPError("one or more duplicate index(es) found"))
    end
    return true
end

function _jl_glpk__check_cols_ids(glp_prob::GLPProb, min_size::Int, num_cols::Int, cols_ids::Vector{Int32})
    cols = @glpk_ccall get_num_cols Int32 (Ptr{Void},) glp_prob.p
    if num_cols < min_size || num_cols > cols
        throw(GLPError("invalid vector size: $num_cols (min=$min_size max=$cols)"))
    end
    if num_cols == 0
        return 0
    end
    if length(col_ids) < num_cols
        throw(GLPError("invalid vector size: declared>=$num_cols actual=$(length(cols_ids))"))
    end
    ind_set = IntSet()
    add_each(ind_set, col_ids[1 : num_cols])
    if min(ind_set) < 1 || max(ind_set) > cols
        throw(GLPError("index out of bounds (min=1 max=$cols)"))
    elseif length(ind_set) != length(col_ids)
        throw(GLPError("one or more duplicate index(es) found"))
    end
    return true
end

function _jl_glpk__check_list_ids(glp_prob::GLPProb, len::Int, list_ids::Vector{Int32})
    if len == 0
        return true
    end
    rows = @glpk_ccall get_num_rows Int32 (Ptr{Void},) glp_prob.p
    cols = @glpk_ccall get_num_cols Int32 (Ptr{Void},) glp_prob.p
    # note1 the documentation does not mention forbidding duplicates in this case
    # note2 the size should already be checked as this function is only called
    #       by glp_print_ranges
    #if len < 0 #|| len > rows + cols
    ##throw(GLPError("invalid vector size: $len (min=0 max=$(rows + cols))"))
    #throw(GLPError("invalid vector size: $len < 0"))
    #end
    #if length(list_ids) < len
    #throw(GLPError("invalid vector size: declared>=$len actual=$(length(list_ids))"))
    #end
    if min(list_ids[1:len]) < 1 || max(list_ids[1:len]) > rows + cols
        throw(GLPError("index out of bounds (min=1 max=$(rows + cols))"))
    end
    return true
end

function _jl_glpk__check_bf_exists(glp_prob::GLPProb)
    ret = @glpk_ccall bf_exists Int32 (Ptr{Void},) glp_prob.p
    if ret == 0
        throw(GLPError("no bf solution found (use glp_factorize)"))
    end
    return true
end


function _jl_glpk__check_copy_names_flag(names::Int)
    if (names != GLP_ON || names != GLP_OFF)
        throw(GLPError("invalid names flag $names (use GLP_ON or GLP_OFF)"))
    end
    return true
end

function _jl_glpk__check_scale_flags(flags::Int32)
    all = (GLP_SF_GM | GLP_SF_EQ | GLP_SF_2N | GLP_SF_SKIP)
    if (flags | all) != all
        throw(GLPError("invalid scale flags $flags"))
    end
    return true
end

function _jl_glpk__check_stat_is_valid(stat::Int)
    if (stat != GLP_BS ||
        stat != GLP_NL ||
        stat != GLP_NU ||
        stat != GLP_NF ||
        stat != GLP_NS)
        throw(GLPError("invalid status $stat (use GLP_BS ir GLP_NL or GLP_NU or GLP_NF or GLP_NS)"))
    end
end

function _jl_glpk__check_adv_basis_flags(flags::Int)
    if flags != 0
        throw(GLPError("adv_basis flags must be set to 0 (found $flags instead)"))
    end
    return true
end

function _jl_glpk__check_simplex_param(glp_param::GLPSimplexParam)
    if (pointer(glp_param) == C_NULL)
        throw(GLPError("glp_param = NULL"))
    end
    return true
end

function _jl_glpk__check_interior_param(glp_param::GLPInteriorParam)
    if (pointer(glp_param) == C_NULL)
        throw(GLPError("glp_param = NULL"))
    end
    return true
end

function _jl_glpk__check_kind_is_valid(kind::Int)
    if (kind != GLP_CV ||
        kind != GLP_IV ||
        kind != GLP_BV)
        throw(GLPError("invalid kind $kind (use GLP_CV or GLP_IV or GLP_bV)"))
    end
    return true
end

function _jl_glpk__check_intopt_param(glp_param::GLPIntoptParam)
    if (pointer(glp_param) == C_NULL)
        throw(GLPError("glp_param = NULL"))
    end
    return true
end

function _jl_glpk__check_file_is_readable(filname::String)
    try
        f = open(f, "r")
    catch err
        throw(GLPError("file $filaneme not readable"))
    end
    close(f)
    return true
end

function _jl_glpk__check_file_is_writable(filname::String)
    try
        f = open(f, "w")
    catch err
        throw(GLPError("file $filaneme not writable"))
    end
    close(f)
    return true
end

function _jl_glpk__check_mps_format(format::Int)
    if (format != GLP_MPS_DECK ||
        format != GLP_MPS_FILE)
        throw(GLPError("invalid MPS format $format (use GLP_MPS_DECK or GLP_MPS_FILE)"))
    end
    return true
end

function _jl_glpk__check_mps_param(param)
    if (param != C_NULL)
        throw(GLPError("MPS param must be C_NULL"))
    end
    return true
end

function _jl_glpk__check_lp_param(param)
    if (param != C_NULL)
        throw(GLPError("LP param must be C_NULL"))
    end
    return true
end

function _jl_glpk__check_read_prob_flags(flags::Int)
    if (flags != 0)
        throw(GLPError("read_prob flags must be 0"))
    end
    return true
end

function _jl_glpk__check_bfcp(glp_param::GLPBasisFactParam)
    if pointer(glp_param) == C_NULL
        throw(GLPError("Invalid GLPBasisFactParam"))
    end
    return true
end


function glp_set_prob_name(glp_prob::GLPProb, name::String)
    _jl_glpk__check_glp_prob(glp_prob)
    @glpk_ccall set_prob_name Void (Ptr{Void}, Ptr{Uint8}) glp_prob.p cstring(name)
end

function glp_set_obj_name(glp_prob::GLPProb, name::String)
    _jl_glpk__check_glp_prob(glp_prob)
    @glpk_ccall set_obj_name Void (Ptr{Void}, Ptr{Uint8}) glp_prob.p cstring(name)
end

function glp_set_row_name(glp_prob::GLPProb, row::Int, name::String)
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_row_is_valid(glp_prob, row)
    @glpk_ccall set_row_name Void (Ptr{Void}, Int32, Ptr{Uint8}) glp_prob.p row cstring(name)
end

function glp_set_col_name(glp_prob::GLPProb, col::Int, name::String)
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_col_is_valid(glp_prob, col)
    @glpk_ccall set_col_name Void (Ptr{Void}, Int32, Ptr{Uint8}) glp_prob.p col cstring(name)
end

function glp_set_obj_dir(glp_prob::GLPProb, dir::Int32)
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_obj_dir_is_valid(dir)
    @glpk_ccall set_obj_dir Void (Ptr{Void}, Int32) glp_prob.p dir
end

function glp_add_rows(glp_prob::GLPProb, rows::Int)
    _jl_glpk__check_glp_prob(glp_prob)
    first_new_row = @glpk_ccall add_rows Int32 (Ptr{Void}, Int32) glp_prob.p rows
    return first_new_row
end

function glp_add_cols(glp_prob::GLPProb, cols::Int)
    _jl_glpk__check_glp_prob(glp_prob)
    first_new_col = @glpk_ccall add_cols Int32 (Ptr{Void}, Int32) glp_prob.p cols
    return first_new_col
end

function glp_set_row_bnds(glp_prob::GLPProb, row::Int, bounds_type::Int32, lb::Real, ub::Real)
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_row_is_valid(glp_prob, row)
    _jl_glpk__check_bounds_type_is_valid(bounds_type)
    _jl_glpk__check_bounds_are_valid(bounds_type, lb, ub)
    @glpk_ccall set_row_bnds Void (Ptr{Void}, Int32, Int32, Float64, Float64) glp_prob.p row bounds_type lb ub
end

function glp_set_col_bnds(glp_prob::GLPProb, col::Int, bounds_type::Int32, lb::Real, ub::Real)
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_col_is_valid(glp_prob, col)
    _jl_glpk__check_bounds_type_is_valid(bounds_type)
    _jl_glpk__check_bounds_are_valid(bounds_type, lb, ub)
    @glpk_ccall set_col_bnds Void (Ptr{Void}, Int32, Int32, Float64, Float64) glp_prob.p col bounds_type lb ub
end

function glp_set_obj_coef(glp_prob::GLPProb, col::Int, coef::Real)
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_col_is_valid_w0(glp_prob, col)
    @glpk_ccall set_obj_coef Void (Ptr{Void}, Int32, Float64) glp_prob.p col coef
end

function glp_set_mat_row{Ti<:Real, Tv<:Real}(glp_prob::GLPProb, row::Int, len::Int, ind::VecOrNothing{Ti}, val::Vector{Float64})
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_vectors_size(len, ind, val)
    _jl_glpk__check_row_is_valid(glp_prob, row)
    ind32 = int32(ind)
    val64 = float64(val)
    off32 = sizeof(Int32)
    off64 = sizeof(Float64)
    ind32p = pointer(ind32) - off32
    val64p = pointer(val64) - off64
    _jl_glpk__check_cols_ids(glp_prob, 0, len, ind32)

    @glpk_ccall set_mat_row Void (Ptr{Void}, Int32, Int32, Ptr{Int32}, Ptr{Float64}) glp_prob row len ind32p val64p
end

function glp_set_mat_col{Ti<:Real, Tv<:Real}(glp_prob::GLPProb, col::Int, len::Int, ind::VecOrNothing{Ti}, val::Vector{Tv})
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_vectors_size(len, ind, val)
    _jl_glpk__check_col_is_valid(glp_prob, col)
    ind32 = int32(ind)
    val64 = float64(val)
    off32 = sizeof(Int32)
    off64 = sizeof(Float64)
    ind32p = pointer(ind32) - off32
    val64p = pointer(val64) - off64
    _jl_glpk__check_rows_ids(glp_prob, 0, len, ind32)

    @glpk_ccall set_mat_col Void (Ptr{Void}, Int32, Int32, Ptr{Int32}, Ptr{Float64}) glp_prob col len ind32p val64p
end

function glp_load_matrix{Ti<:Real, Tv<:Real}(glp_prob::GLPProb, numel::Int, ia::VecOrNothing{Ti}, ja::VecOrNothing{Ti}, ar::VecOrNothing{Tv})
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_vectors_size(numel, ia, ja, ar)
    if numel == 0
        return
    end
    ia32 = int32(ia)
    ja32 = int32(ja)
    ar64 = float64(ar)
    _jl_glpk__check_indices_vectors_dup(glp_prob, numel, ia32, ja32)

    off32 = sizeof(Int32)
    off64 = sizeof(Float64)
    ia32p = pointer(ia32) - off32
    ja32p = pointer(ja32) - off32
    ar64p = pointer(ar64) - off64

    @glpk_ccall load_matrix Void (Ptr{Void}, Int32, Ptr{Int32}, Ptr{Int32}, Ptr{Float64}) glp_prob.p numel ia32p ja32p ar64p
end

glp_load_matrix{Ti, Tj, Tv}(glp_prob::GLPProb, ia::AbstractVector{Ti}, ja::AbstractVector{Tj}, ar::AbstractVector{Tv}) =
    glp_load_matrix(glp_prob, length(ar), ia, ja, ar)

function glp_load_matrix{Ti, Tv}(glp_prob::GLPProb, a::SparseMatrixCSC{Tv, Ti})
    (ia, ja, ar) = find(a)
    glp_load_matrix(glp_prob, ia, ja, ar)
end

function glp_check_dup{Ti<:Real}(rows::Int, cols::Int, numel::Int, ia::VecOrNothing{Ti}, ja::VecOrNothing{Ti})
    _jl_glpk__check_rows_and_cols(rows, cols)
    _jl_glpk__check_vectors_size(numel, ia, ja)
    ia32 = int32(ia)
    ja32 = int32(ja)

    off32 = sizeof(Int32)
    ia32p = pointer(ia32) - off32
    ja32p = pointer(ja32) - off32

    k = @glpk_ccall check_dup Int32 (Int32, Int32, Int32, Ptr{Int32}, Ptr{Int32}) rows cols numel ia32p ja32p
    return k
end

glp_check_dup{Ti}(rows::Int, cols::Int, ia::AbstractVector{Ti}, ja::AbstractVector{Ti}) =
    glp_check_dup(rows, cols, length(ia), ia, ja)

function glp_sort_matrix(glp_prob::GLPProb)
    _jl_glpk__check_glp_prob(glp_prob)
    @glpk_ccall sort_matrix Void (Ptr{Void},) glp_prob.p
end

function glp_del_rows{Ti<:Real}(glp_prob::GLPProb, num_rows::Int, rows_ids::AbstractVector{Ti})
    _jl_glpk__check_glp_prob(glp_prob)
    rows_ids32 = int32(rows_ids)
    _jl_glpk__check_rows_ids(glp_prob, 1, num_rows, rows_ids32)
    
    off32 = sizeof(Int32)
    rows_ids32p = pointer(rows_ids32) - off32
    @glpk_ccall del_rows Void (Ptr{Void}, Int, Ptr{Int32}) glp_prob.p num_rows rows_ids32p
end

function glp_del_cols{Ti<:Real}(glp_prob::GLPProb, num_cols::Int, cols_ids::AbstractVector{Ti})
    _jl_glpk__check_glp_prob(glp_prob)
    cols_ids32 = int32(cols_ids)
    _jl_glpk__check_cols_ids(glp_prob, 1, num_cols, cols_ids32)
    
    off32 = sizeof(Int32)
    cols_ids32p = pointer(cols_ids32) - off32
    @glpk_ccall del_cols Void (Ptr{Void}, Int, Ptr{Int32}) glp_prob.p num_cols cols_ids32p
end

function glp_copy_prob(glp_prob_dest::GLPProb, glp_prob::GLPProb, copy_names::Int)
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_copy_names_flag(copy_names)
    @glpk_ccall copy_prob Void (Ptr{Void}, Ptr{Void}, Int32) glp_prob_dest.p glp_prob.p names
end

function glp_erase_prob(glp_prob::GLPProb)
    _jl_glpk__check_glp_prob(glp_prob)
    @glpk_ccall erase_prob Void (Ptr{Void},) glp_prob.p
end

function glp_get_prob_name(glp_prob::GLPProb)
    _jl_glpk__check_glp_prob(glp_prob)
    name_cstr = @glpk_ccall get_prob_name Ptr{Uint8} (Ptr{Void},) glp_prob.p
    if name_cstr == C_NULL
        return ""
    else
        return string(name_cstr)
    end
end

function glp_get_obj_name(glp_prob::GLPProb)
    _jl_glpk__check_glp_prob(glp_prob)
    name_cstr = @glpk_ccall get_obj_name Ptr{Uint8} (Ptr{Void},) glp_prob.p
    if name_cstr == C_NULL
        return ""
    else
        return string(name_cstr)
    end
end

function glp_get_obj_dir(glp_prob::GLPProb)
    _jl_glpk__check_glp_prob(glp_prob)
    obj_dir = @glpk_ccall get_obj_dir Int32 (Ptr{Void},) glp_prob.p
    return obj_dir
end

function glp_get_num_rows(glp_prob::GLPProb)
    _jl_glpk__check_glp_prob(glp_prob)
    rows = @glpk_ccall get_num_rows Int32 (Ptr{Void},) glp_prob.p
    return rows
end

function glp_get_num_cols(glp_prob::GLPProb)
    _jl_glpk__check_glp_prob(glp_prob)
    cols = @glpk_ccall get_num_cols Int32 (Ptr{Void},) glp_prob.p
    return cols
end

function glp_get_row_name(glp_prob::GLPProb, row::Int)
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_row_is_valid(glp_prob, row)
    name_cstr = @glpk_ccall get_row_name Ptr{Uint8} (Ptr{Void}, Int32) glp_prob.p row
    if name_cstr == C_NULL
        return ""
    else
        return string(name_cstr)
    end
end

function glp_get_col_name(glp_prob::GLPProb, col::Int)
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_col_is_valid(glp_prob, col)
    name_cstr = @glpk_ccall get_col_name Ptr{Uint8} (Ptr{Void}, Int32) glp_prob.p col
    if name_cstr == C_NULL
        return ""
    else
        return string(name_cstr)
    end
end

function glp_get_row_type(glp_prob::GLPProb, row::Int)
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_row_is_valid(glp_prob, row)
    row_type = @glpk_ccall get_row_type Int32 (Ptr{Void}, Int32) glp_prob.p row
    return row_type
end

function glp_get_row_lb(glp_prob::GLPProb, row::Int)
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_row_is_valid(glp_prob, row)
    row_lb = @glpk_ccall get_row_lb Float64 (Ptr{Void}, Int32) glp_prob.p row
    return row_lb
end

function glp_get_row_ub(glp_prob::GLPProb, row::Int)
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_row_is_valid(glp_prob, row)
    row_ub = @glpk_ccall get_row_ub Float64 (Ptr{Void}, Int32) glp_prob.p row
    return row_ub
end

function glp_get_col_type(glp_prob::GLPProb, col::Int)
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_col_is_valid(glp_prob, col)
    col_type = @glpk_ccall get_col_type Int32 (Ptr{Void}, Int32) glp_prob.p col
    return col_type
end

function glp_get_col_lb(glp_prob::GLPProb, col::Int)
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_col_is_valid(glp_prob, col)
    col_lb = @glpk_ccall get_col_lb Float64 (Ptr{Void}, Int32) glp_prob.p col
    return col_lb
end

function glp_get_col_ub(glp_prob::GLPProb, col::Int)
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_col_is_valid(glp_prob, col)
    col_ub = @glpk_ccall get_col_ub Float64 (Ptr{Void}, Int32) glp_prob.p col
    return col_ub
end

function glp_get_obj_coef(glp_prob::GLPProb, col::Int)
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_col_is_valid_w0(glp_prob, col)
    col_ub = @glpk_ccall get_obj_coef Float64 (Ptr{Void}, Int32) glp_prob.p col
    return col_ub
end

function glp_get_num_nz(glp_prob::GLPProb)
    _jl_glpk__check_glp_prob(glp_prob)
    num_nz = @glpk_ccall get_num_nz Int32 (Ptr{Void},) glp_prob.p
    return num_nz
end

function glp_get_mat_row(glp_prob::GLPProb, row::Int, ind::VecOrNothing{Int32}, val::VecOrNothing{Float64})
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_row_is_valid(glp_prob, row)
    numel = @glpk_ccall get_mat_row Int32 (Ptr{Void}, Int32, Ptr{Int32}, Ptr{Float64}) glp_prob row C_NULL C_NULL
    if numel == 0
        return 0
    end
    _jl_glpk__check_vectors_size(numel, ind, val)
    off32 = sizeof(Int32)
    off64 = sizeof(Float64)
    ind32p = pointer(ind) - off32
    val64p = pointer(val) - off64
    numel = @glpk_ccall get_mat_row Int32 (Ptr{Void}, Int32, Ptr{Int32}, Ptr{Float64}) glp_prob row ind32p int64p
end

function glp_get_mat_col(glp_prob::GLPProb, col::Int, ind::VecOrNothing{Int32}, val::VecOrNothing{Float64})
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_col_is_valid(glp_prob, col)
    numel = @glpk_ccall get_mat_col Int32 (Ptr{Void}, Int32, Ptr{Int32}, Ptr{Float64}) glp_prob col C_NULL C_NULL
    if numel == 0
        return 0
    end
    _jl_glpk__check_vectors_size(numel, ind, val)
    off32 = sizeof(Int32)
    off64 = sizeof(Float64)
    ind32p = pointer(ind) - off32
    val64p = pointer(val) - off64
    numel = @glpk_ccall get_mat_col Int32 (Ptr{Void}, Int32, Ptr{Int32}, Ptr{Float64}) glp_prob col ind32p int64p
end

function glp_create_index(glp_prob::GLPProb)
    _jl_glpk__check_glp_prob(glp_prob)
    @glpk_ccall create_index Void (Ptr{Void},) glp_prob.p
end

function glp_find_row(glp_prob::GLPProb, name::String)
    _jl_glpk__check_glp_prob(glp_prob)
    row = @glpk_ccall find_row Int32 (Ptr{Void}, Ptr{Uint8}) glp_prob.p cstring(name)
    return row
end

function glp_find_col(glp_prob::GLPProb, name::String)
    _jl_glpk__check_glp_prob(glp_prob)
    col = @glpk_ccall find_col Int32 (Ptr{Void}, Ptr{Uint8}) glp_prob.p cstring(name)
    return col
end

function glp_delete_index(glp_prob::GLPProb)
    _jl_glpk__check_glp_prob(glp_prob)
    @glpk_ccall delete_index Void (Ptr{Void},) glp_prob.p
end

function glp_set_rii(glp_prob::GLPProb, row::Int, rii::Real)
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_row_is_valid(glp_prob, row)
    @glpk_ccall set_rii Void (Ptr{Void}, Int32, Float64) glp_prob.p row rii
end

function glp_set_sjj(glp_prob::GLPProb, col::Int, sjj::Real)
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_col_is_valid(glp_prob, col)
    @glpk_ccall set_sjj Void (Ptr{Void}, Int32, Float64) glp_prob.p col sjj
end

function glp_get_rii(glp_prob::GLPProb, row::Int)
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_row_is_valid(glp_prob, row)
    rii = @glpk_ccall get_rii Float64 (Ptr{Void}, Int32) glp_prob.p row
    return rii
end

function glp_get_sjj(glp_prob::GLPProb, col::Int)
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_col_is_valid(glp_prob, col)
    sjj = @glpk_ccall ret_sjj Float64 (Ptr{Void}, Int32) glp_prob.p col
    return sjj
end

function glp_scale_prob(glp_prob::GLPProb, flags::Int32)
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_scale_flags(flags)
    @glpk_ccall scale_prob Void (Ptr{Void}, Int32) glp_prob.p flags
end

function glp_unscale_prob(glp_prob::GLPProb)
    _jl_glpk__check_glp_prob(glp_prob)
    @glpk_ccall unscale_prob Void (Ptr{Void},) glp_prob.p
end

function glp_set_row_stat(glp_prob::GLPProb, row::Int, stat::Int)
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_row_is_valid(glp_prob, row)
    _jl_glpk__check_stat_is_valid(stat)
    @glpk_ccall set_row_stat Void (Ptr{Void}, Int32, Int32) glp_prob.p row stat
end

function glp_set_col_stat(glp_prob::GLPProb, col::Int, stat::Int)
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_col_is_valid(glp_prob, col)
    _jl_glpk__check_stat_is_valid(stat)
    @glpk_ccall set_col_stat Void (Ptr{Void}, Int32, Int32) glp_prob.p col stat
end

function glp_std_basis(glp_prob::GLPProb)
    _jl_glpk__check_glp_prob(glp_prob)
    @glpk_ccall std_basis Void (Ptr{Void},) glp_prob.p
end

function glp_adv_basis(glp_prob::GLPProb, flags::Int)
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_adv_basis_flags(flags)
    @glpk_ccall adv_basis Void (Ptr{Void}, Int32) glp_prob.p flags
end

function glp_cpx_basis(glp_prob::GLPProb)
    _jl_glpk__check_glp_prob(glp_prob)
    @glpk_ccall cpx_basis Void (Ptr{Void},) glp_prob.p
end

function glp_simplex{Tp<:Union(GLPSimplexParam, Nothing)}(glp_prob::GLPProb, glp_param::Tp)
    _jl_glpk__check_glp_prob(glp_prob)
    if glp_param == nothing
        #println("null ptr")
        param_ptr = C_NULL
    else
        #println("nonnull ptr")
        param_ptr = pointer(glp_param)
    end
    ret = @glpk_ccall simplex Int32 (Ptr{Void}, Ptr{Void}) glp_prob.p param_ptr
    #ret = @glpk_ccall simplex Int32 (Ptr{Void}, Ptr{Void}) glp_prob.p C_NULL
    return ret
end

glp_simplex(glp_prob::GLPProb) =
    glp_simplex(glp_prob, nothing)

function glp_exact{Tp<:Union(GLPSimplexParam, Nothing)}(glp_prob::GLPProb, glp_param::Tp)
    _jl_glpk__check_glp_prob(glp_prob)
    if glp_param == nothing
        param_ptr = C_NULL
    else
        param_ptr = pointer(glp_param)
    end
    ret = @glpk_ccall exact Int32 (Ptr{Void}, Ptr{Void}) glp_prob.p param_ptr
    return ret
end

glp_exact(glp_prob::GLPProb) =
    glp_exact(glp_prob, nothing)

function glp_init_smcp(glp_param::GLPSimplexParam)
    _jl_glpk__check_simplex_param(glp_param)
    @glpk_ccall init_smcp Int32 (Ptr{Void}, Ptr{Void}) pointer(glp_param)
end

function glp_get_status(glp_prob::GLPProb)
    _jl_glpk__check_glp_prob(glp_prob)
    ret = @glpk_ccall get_status Int32 (Ptr{Void},) glp_prob.p
    return ret
end

function glp_get_prim_stat(glp_prob::GLPProb)
    _jl_glpk__check_glp_prob(glp_prob)
    ret = @glpk_ccall get_prim_stat Int32 (Ptr{Void},) glp_prob.p
    return ret
end

function glp_get_dual_stat(glp_prob::GLPProb)
    _jl_glpk__check_glp_prob(glp_prob)
    ret = @glpk_ccall get_dual_stat Int32 (Ptr{Void},) glp_prob.p
    return ret
end

function glp_get_obj_val(glp_prob::GLPProb)
    _jl_glpk__check_glp_prob(glp_prob)
    ret = @glpk_ccall get_obj_val Float64 (Ptr{Void},) glp_prob.p
    return ret
end

function glp_get_row_stat(glp_prob::GLPProb, row::Int)
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_row_is_valid(glp_prob, row)
    ret = @glpk_ccall get_row_stat Int32 (Ptr{Void}, Int32) glp_prob.p row
    return ret
end

function glp_get_row_prim(glp_prob::GLPProb, row::Int)
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_row_is_valid(glp_prob, row)
    ret = @glpk_ccall get_row_prim Float64 (Ptr{Void}, Int32) glp_prob.p row
    return ret
end

function glp_get_row_dual(glp_prob::GLPProb, row::Int)
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_row_is_valid(glp_prob, row)
    ret = @glpk_ccall get_row_dual Float64 (Ptr{Void}, Int32) glp_prob.p row
    return ret
end


function glp_get_col_stat(glp_prob::GLPProb, col::Int)
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_col_is_valid(glp_prob, col)
    ret = @glpk_ccall get_col_stat Int32 (Ptr{Void}, Int32) glp_prob.p col
    return ret
end

function glp_get_col_prim(glp_prob::GLPProb, col::Int)
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_col_is_valid(glp_prob, col)
    ret = @glpk_ccall get_col_prim Float64 (Ptr{Void}, Int32) glp_prob.p col
    return ret
end

function glp_get_col_dual(glp_prob::GLPProb, col::Int)
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_col_is_valid(glp_prob, col)
    ret = @glpk_ccall get_col_dual Float64 (Ptr{Void}, Int32) glp_prob.p col
    return ret
end

function glp_get_unbnd_ray(glp_prob::GLPProb)
    _jl_glpk__check_glp_prob(glp_prob)
    ret = @glpk_ccall get_unbnd_ray Int32 (Ptr{Void},) glp_prob.p
    return ret
end

function glp_interior{Tp<:Union(GLPInteriorParam, Nothing)}(glp_prob::GLPProb, glp_param::Tp)
    _jl_glpk__check_glp_prob(glp_prob)
    if glp_param == nothing
        param_ptr::Ptr{Void} = C_NULL
    else
        param_ptr = glp_param.p
    end
    ret = @glpk_ccall interior Int32 (Ptr{Void}, Ptr{Void}) glp_prob.p param_ptr
    return ret
end

glp_interior(glp_prob::GLPProb) = glp_interior(glp_prob, nothing)

function glp_init_iptcp(glp_param::GLPInteriorParam)
    _jl_glpk__check_interior_param(glp_param)
    @glpk_ccall init_iptcp Int32 (Ptr{Void}, Ptr{Void}) glp_param.p
end

function glp_ipt_status(glp_prob::GLPProb)
    _jl_glpk__check_glp_prob(glp_prob)
    ret = @glpk_ccall ipt_status Int32 (Ptr{Void},) glp_prob.p
    return ret
end

function glp_ipt_obj_val(glp_prob::GLPProb)
    _jl_glpk__check_glp_prob(glp_prob)
    ret = @glpk_ccall ipt_obj_val Float64 (Ptr{Void},) glp_prob.p
    return ret
end

function glp_ipt_row_prim(glp_prob::GLPProb, row::Int)
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_row_is_valid(glp_prob, row)
    ret = @glpk_ccall ipt_row_prim Float64 (Ptr{Void}, Int32) glp_prob.p row
    return ret
end

function glp_ipt_row_dual(glp_prob::GLPProb, row::Int)
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_row_is_valid(glp_prob, row)
    ret = @glpk_ccall ipt_row_dual Float64 (Ptr{Void}, Int32) glp_prob.p row
    return ret
end

function glp_ipt_col_prim(glp_prob::GLPProb, col::Int)
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_col_is_valid(glp_prob, col)
    ret = @glpk_ccall ipt_col_prim Float64 (Ptr{Void}, Int32) glp_prob.p col
    return ret
end

function glp_ipt_col_dual(glp_prob::GLPProb, col::Int)
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_col_is_valid(glp_prob, col)
    ret = @glpk_ccall ipt_col_dual Float64 (Ptr{Void}, Int32) glp_prob.p col
    return ret
end

function glp_set_col_kind(glp_prob::GLPProb, col::Int, kind::Int)
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_col_is_valid(glp_prob, col)
    _jl_glpk__check_kind_is_valid(kind)
    @glpk_ccall set_col_kind Void (Ptr{Void}, Int32, Int32) glp_prob.p col kind
end

function glp_get_col_kind(glp_prob::GLPProb, col::Int)
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_col_is_valid(glp_prob, col)
    kind = @glpk_ccall get_col_kind Int32 (Ptr{Void}, Int32) glp_prob.p col
    return kind
end

function glp_get_num_int(glp_prob::GLPProb)
    _jl_glpk__check_glp_prob(glp_prob)
    num_int = @glpk_ccall get_num_int Int32 (Ptr{Void},) glp_prob.p
    return num_int
end

function glp_get_num_bin(glp_prob::GLPProb)
    _jl_glpk__check_glp_prob(glp_prob)
    num_bin = @glpk_ccall get_num_bin Int32 (Ptr{Void},) glp_prob.p
    return num_bin
end

function glp_intopt{Tp<:Union(GLPIntoptParam, Nothing)}(glp_prob::GLPProb, glp_param::Tp)
    _jl_glpk__check_glp_prob(glp_prob)
    if glp_param == nothing
        param_ptr::Ptr{Void} = C_NULL
    else
        param_ptr = glp_param.p
    end
    ret = @glpk_ccall intopt Int32 (Ptr{Void}, Ptr{Void}) glp_prob.p param_ptr
    return ret
end

glp_intopt(glp_prob::GLPProb) = glp_intopt(glp_prob, nothing)

function glp_init_iocp(glp_param::GLPIntoptParam)
    _jl_glpk__check_intopt_param(glp_param)
    @glpk_ccall init_iocp Int32 (Ptr{Void}, Ptr{Void}) glp_param.p
end

function glp_mip_status(glp_prob::GLPProb)
    _jl_glpk__check_glp_prob(glp_prob)
    ret = @glpk_ccall mip_status Int32 (Ptr{Void},) glp_prob.p
    return ret
end

function glp_mip_obj_val(glp_prob::GLPProb)
    _jl_glpk__check_glp_prob(glp_prob)
    ret = @glpk_ccall mip_obj_val Float64 (Ptr{Void},) glp_prob.p
    return ret
end

function glp_mip_row_val(glp_prob::GLPProb, row::Int)
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_row_is_valid(glp_prob, row)
    ret = @glpk_ccall mip_row_val Float64 (Ptr{Void}, Int32) glp_prob.p row
    return ret
end

function glp_mip_col_val(glp_prob::GLPProb, col::Int)
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_col_is_valid(glp_prob, col)
    ret = @glpk_ccall mip_col_val Float64 (Ptr{Void}, Int32) glp_prob.p col
    return ret
end

#TODO
#function lpx_check_kkt(glp_prob::GLPProb, scaled::Int, kkt)

function glp_read_mps(glp_prob::GLPProb, format::Int, param, filename::String)
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_mps_format(format)
    _jl_glpk__check_mps_par(param)
    _jl_glpk__check_file_is_readable(filename)
    ret = @glpk_ccall read_mps Int32 (Ptr{Void}, Int32, Ptr{Void}, Ptr{Uint8}) glp_prob.p format param cstring(filename)
    return ret
end

glp_read_mps(glp_prob::GLPProb, format::Int, filename::String) =
    glp_read_mps(glp_prob, format, C_NULL, filename)

function glp_write_mps(glp_prob::GLPProb, format::Int, param, filename::String)
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_mps_format(format)
    _jl_glpk__check_mps_par(param)
    _jl_glpk__check_file_is_writable(filename)
    ret = @glpk_ccall write_mps Int32 (Ptr{Void}, Int32, Ptr{Void}, Ptr{Uint8}) glp_prob.p format param cstring(filename)
    return ret
end

glp_write_mps(glp_prob::GLPProb, format::Int, filename::String) =
    glp_write_mps(glp_prob, format, C_NULL, filename)

function glp_read_lp(glp_prob::GLPProb, param, filename::String)
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_lp_par(param)
    _jl_glpk__check_file_is_readable(filename)
    ret = @glpk_ccall read_lp Int32 (Ptr{Void}, Ptr{Void}, Ptr{Uint8}) glp_prob.p param cstring(filename)
    return ret
end

glp_read_lp(glp_prob::GLPProb, filename::String) = 
    glp_read_lp(glp_prob, C_NULL, filename)

function glp_write_lp(glp_prob::GLPProb, param, filename::String)
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_lp_par(param)
    _jl_glpk__check_file_is_writable(filename)
    ret = @glpk_ccall write_lp Int32 (Ptr{Void}, Ptr{Void}, Ptr{Uint8}) glp_prob.p param cstring(filename)
    return ret
end

glp_write_lp(glp_prob::GLPProb, filename::String) = 
    glp_write_lp(glp_prob, C_NULL, filename)

function glp_read_prob(glp_prob::GLPProb, flags::Int, filename::String)
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_read_prob_flags(flags)
    _jl_glpk__check_file_is_readable(filename)
    ret = @glpk_ccall read_prob Int32 (Ptr{Void}, Int32, Ptr{Uint8}) glp_prob.p flags cstring(filename)
    return ret
end

glp_read_prob(glp_prob::GLPProb, filename::String) =
    glp_read_prob(glp_prob, 0, filename)

function glp_write_prob(glp_prob::GLPProb, flags::Int, filename::String)
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_write_prob_flags(flags)
    _jl_glpk__check_file_is_writable(filename)
    ret = @glpk_ccall write_prob Int32 (Ptr{Void}, Int32, Ptr{Uint8}) glp_prob.p flags cstring(filename)
    return ret
end

glp_write_prob(glp_prob::GLPProb, filename::String) =
    glp_write_prob(glp_prob, 0, filename)

#TODO
#function glp_mpl_alloc_wksp()
#function glp_mpl_read_model(glp_tran::GLPTran, filename::String, skip::Int)
#function glp_mpl_read_data(glp_tran::GLPTran, filename::String)
#function glp_mpl_generate(glp_tran::GLPTran, filename::String)
#funciton glp_mpl_build_prob(glp_tran::GLPTran, glp_prob::GLPProb)
#function glp_mpl_postsolve(glp_tran::GLPTran, glp_prob::GLPPRob, sol::Int)
#function glp_mpl_free_wksp(glp_tran::GLPTran)

function glp_print_sol(glp_prob::GLPProb, filename::String)
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_file_is_writable(filename)
    ret = @glpk_ccall print_sol Int32 (Ptr{Void}, Ptr{Uint8}) glp_prob.p cstring(filename)
    return ret
end

function glp_read_sol(glp_prob::GLPProb, filename::String)
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_file_is_readable(filename)
    ret = @glpk_ccall read_sol Int32 (Ptr{Void}, Ptr{Uint8}) glp_prob.p cstring(filename)
    return ret
end

function glp_write_sol(glp_prob::GLPProb, filename::String)
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_file_is_writable(filename)
    ret = @glpk_ccall write_sol Int32 (Ptr{Void}, Ptr{Uint8}) glp_prob.p cstring(filename)
    return ret
end

function glp_print_ipt(glp_prob::GLPProb, filename::String)
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_file_is_writable(filename)
    ret = @glpk_ccall print_ipt Int32 (Ptr{Void}, Ptr{Uint8}) glp_prob.p cstring(filename)
    return ret
end

function glp_read_ipt(glp_prob::GLPProb, filename::String)
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_file_is_readable(filename)
    ret = @glpk_ccall read_ipt Int32 (Ptr{Void}, Ptr{Uint8}) glp_prob.p cstring(filename)
    return ret
end

function glp_write_ipt(glp_prob::GLPProb, filename::String)
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_file_is_writable(filename)
    ret = @glpk_ccall write_ipt Int32 (Ptr{Void}, Ptr{Uint8}) glp_prob.p cstring(filename)
    return ret
end

function glp_print_mip(glp_prob::GLPProb, filename::String)
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_file_is_writable(filename)
    ret = @glpk_ccall print_mip Int32 (Ptr{Void}, Ptr{Uint8}) glp_prob.p cstring(filename)
    return ret
end

function glp_read_mip(glp_prob::GLPProb, filename::String)
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_file_is_readable(filename)
    ret = @glpk_ccall read_mip Int32 (Ptr{Void}, Ptr{Uint8}) glp_prob.p cstring(filename)
    return ret
end

function glp_write_mip(glp_prob::GLPProb, filename::String)
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_file_is_writable(filename)
    ret = @glpk_ccall write_mip Int32 (Ptr{Void}, Ptr{Uint8}) glp_prob.p cstring(filename)
    return ret
end

function glp_print_ranges(glp_prob::GLPProb, len::Int, list::VecOrNothing{Int32}, flags::Int, filename::String)
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_vectors_size(len, list)
    _jl_glpk__check_list_ids(glp_prob, len, list)
    _jl_glpk_bf_exists(glp_prob.p)
    _jl_glpk__check_file_is_writable(filename)

    ind32 = int32(list)
    off32 = sizeof(Int32)
    ind32p = pointer(ind32) - off32

    ret = @glpk_ccall print_ranges Int32 (Ptr{Void}, Int32, Ptr{Int32}, Int32, Ptr{Uint8}) glp_prob.p len ind32p cstring(filename)
end

function glp_bf_exists(glp_prob::GLPProb)
    _jl_glpk__check_glp_prob(glp_prob)
    ret = @glpk_ccall bf_exists Int32 (Ptr{Void},) glp_prob.p
    return ret
end

function glp_factorize(glp_prob::GLPProb)
    _jl_glpk__check_glp_prob(glp_prob)
    ret = @glpk_ccall factorize Int32 (Ptr{Void},) glp_prob.p
    return ret
end

function glp_bf_updated(glp_prob::GLPProb)
    _jl_glpk__check_glp_prob(glp_prob)
    ret = @glpk_ccall bf_updated Int32 (Ptr{Void},) glp_prob.p
    return ret
end

function glp_get_bfcp(glp_prob::GLPProb, glp_param::GLPBasisFactParam)
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_bfcp(glp_prob)
    @glpk_ccall get_bfcp Void (Ptr{Void}, Ptr{Void}) glp_prob.p pointer(glp_prob)
end

function glp_set_bfcp(glp_prob::GLPProb, glp_param::GLPBasisFactParam)
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_bfcp(glp_prob)
    @glpk_ccall set_bfcp Void (Ptr{Void}, Ptr{Void}) glp_prob.p pointer(glp_prob)
end

function glp_get_bhead(glp_prob::GLPProb, k::Int)
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_row_is_valid(glp_prob, k)
    ret = @glpk_ccall get_bhead Int32 (Ptr{Void}, Int32) glp_prob.p k
    return ret
end

function glp_get_row_bind(glp_prob::GLPProb, row::Int)
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_row_is_valid(glp_prob, row)
    ret = @glpk_ccall get_row_bind Int32 (Ptr{Void}, Int32) glp_prob.p k
    return ret
end

function glp_get_col_bind(glp_prob::GLPProb, col::Int)
    _jl_glpk__check_glp_prob(glp_prob)
    _jl_glpk__check_col_is_valid(glp_prob, col)
    ret = @glpk_ccall get_col_bind Int32 (Ptr{Void}, Int32) glp_prob.p k
    return ret
end

function glp_ftran(glp_prob::GLPProb, x::Vector{Float64})
    _jl_glpk__check_glp_prob(glp_prob)
    rows = @glpk_ccall get_num_rows Int32 (Ptr{Void},) glp_prob.p
    _jl_glpk__check_vectors_size(rows, x)
    off64 = sizeof(Float64)
    x64p = pointer(x64) - off64
    rows = @glpk_ccall glp_ftran Void (Ptr{Void}, Ptr{Float64}) glp_prob.p x64p
end

function glp_btran(glp_prob::GLPProb, x::Vector{Float64})
    _jl_glpk__check_glp_prob(glp_prob)
    rows = @glpk_ccall get_num_rows Int32 (Ptr{Void},) glp_prob.p
    _jl_glpk__check_vectors_size(rows, x)
    off64 = sizeof(Float64)
    x64p = pointer(x64) - off64
    rows = @glpk_ccall glp_btran Void (Ptr{Void}, Ptr{Float64}) glp_prob.p x64p
end

function glp_warm_up(glp_prob::GLPProb)
    _jl_glpk__check_glp_prob(glp_prob)
    ret = @glpk_ccall warm_up Int32 (Ptr{Void},) glp_prob.p
    return ret
end

#TODO
#function glp_eval_tab_row(glp_prob::GLPProb, k::Int, ind::AbstractVector{Int}, val::AbstractVector{Float})
#function glp_eval_tab_col(glp_prob::GLPProb, k::Int, ind::AbstractVector{Int}, val::AbstractVector{Float})
#function glp_transform_row(glp_prob::GLPProb, len::Int, ind::AbstractVector{Int}, val::AbstractVector{Float})
#function glp_transform_col(glp_prob::GLPProb, len::Int, ind::AbstractVector{Int}, val::AbstractVector{Float})
#function glp_prim_rest(glp_prob::GLPProb, len::Int, ind::AbstractVector{Int}, val::AbstractVector{Float}, dir::Int, eps::Float)
#function glp_dual_rest(glp_prob::GLPProb, len::Int, ind::AbstractVector{Int}, val::AbstractVector{Float}, dir::Int, eps::Float)
#function glp_analyze_bound(glp_prob::GLPProb, k::Int, limit1::Ptr{Float64}, var1::Ptr{Int32}, limit2::Ptr{Float64}, var2::Ptr{Int32})
#function glp_analyze_coef(glp_prob::GLPProb, k::Int, coef1::Ptr{Float64}, var1::Ptr{Int32}, limit1::Ptr{Float64}, coef2::Ptr{Float64}, var2::Ptr{Int32}, limit2::Ptr{Float64})
#
#
# ...... and many more ......
#

function linprog_simplex{T<:Real, P<:Union(GLPSimplexParam, Nothing)}(f::AbstractVector{T}, A::MatOrNothing{T}, b::VecOrNothing{T},
        Aeq::MatOrNothing{T}, beq::VecOrNothing{T},
        lb::VecOrNothing{T}, ub::VecOrNothing{T},
        params::P)
    lp = GLPProb()
    glp_set_obj_dir(lp, GLP_MIN)

    n = size(f, 1)

    m = _jl_linprog__check_A_b(A, b, n)
    meq = _jl_linprog__check_A_b(Aeq, beq, n)

    has_lb, has_ub = _jl_linprog__check_lb_ub(lb, ub, n)

    #println("n=$n m=$m meq=$meq has_lb=$has_lb ub=$has_ub")

    if m > 0
        glp_add_rows(lp, m)
        for r = 1 : m
            #println("  r=$r b=$(b[r])")
            glp_set_row_bnds(lp, r, GLP_UP, 0.0, b[r])
        end
    end
    if meq > 0
        glp_add_rows(lp, meq)
        for r = 1 : meq
            r0 = r + m
            #println("  r=$r r0=$r0 beq=$(beq[r])")
            glp_set_row_bnds(lp, r0, GLP_FX, beq[r], beq[r])
        end
    end

    glp_add_cols(lp, n)

    for c = 1 : n
        glp_set_obj_coef(lp, c, f[c])
        #println("  c=$c f=$(f[c])")
    end

    if has_lb && has_ub
        for c = 1 : n
            #println("  c=$c lb=$(lb[c]) ub=$(ub[c])")
            bounds_type = (lb[c] != ub[c] ? GLP_DB : GLP_FX)
            glp_set_col_bnds(lp, c, bounds_type, lb[c], ub[c])
        end
    elseif has_lb
        for c = 1 : n
            #println("  c=$c lb=$(lb[c])")
            glp_set_col_bnds(lp, c, GLP_LO, lb[c], 0.0)
        end
    elseif has_ub
        for c = 1 : n
            #println("  c=$c ub=$(ub[c])")
            glp_set_col_bnds(lp, c, GLP_UP, 0.0, ub[c])
        end
    end

    if (m > 0 && issparse(A)) && (meq > 0 && issparse(Aeq))
        (ia, ja, ar) = find([A; Aeq])
    elseif (m > 0 && issparse(A)) && (meq == 0)
        (ia, ja, ar) = find(A)
    elseif (m == 0) && (meq > 0 && issparse(Aeq))
        (ia, ja, ar) = find(Aeq)
    else
        (ia, ja, ar) = _jl_linprog__dense_matrices_to_glp_format(m, meq, n, A, Aeq)
    end
    #println("ia=$ia")
    #println("ja=$ja")
    #println("ar=$ar")

    glp_load_matrix(lp, ia, ja, ar)

    # TODO more methods
    ret = glp_simplex(lp, params)
    #println("ret=$ret")

    if ret == 0
        z = glp_get_obj_val(lp)
        x = zeros(Float64, n)
        for c = 1 : n
            x[c] = glp_get_col_prim(lp, c)
        end
        #glp_delete_prob(lp)
        return (z, x, ret)
    else
        #glp_delete_prob(lp)
        # throw exception here ?
        return (nothing, nothing, ret)
    end
end

linprog_simplex{T<:Real}(f::AbstractVector{T}, A::MatOrNothing{T}, b::VecOrNothing{T}) = 
        linprog_simplex(f, A, b, nothing, nothing, nothing, nothing, nothing)

linprog_simplex{T<:Real}(f::AbstractVector{T}, A::MatOrNothing{T}, b::VecOrNothing{T},
        Aeq::MatOrNothing{T}, beq::VecOrNothing{T}) = 
        linprog_simplex(f, A, b, Aeq, beq, nothing, nothing, nothing)

linprog_simplex{T<:Real}(f::AbstractVector{T}, A::MatOrNothing{T}, b::VecOrNothing{T},
        Aeq::MatOrNothing{T}, beq::VecOrNothing{T}, lb::VecOrNothing{T},
        ub::VecOrNothing{T}) = 
        linprog_simplex(f, A, b, Aeq, beq, lb, ub, nothing)

function _jl_linprog__check_A_b{T}(A::MatOrNothing{T}, b::VecOrNothing{T}, n::Int)
    m = 0
    if !_jl_glpk__is_empty(A)
        if size(A, 2) != n
            error("invlid A size: $(size(A))")
        end
        m = size(A, 1)
        if _jl_glpk__is_empty(b)
            error("b is empty but a is not")
        end
        if size(b, 1) != m
            #printf(f"m=%i\n", m)
            error("invalid b size: $(size(b))")
        end
    else
        if !_jl_glpk__is_empty(b)
            error("A is empty but b is not")
        end
    end
    return m
end

function _jl_linprog__check_lb_ub{T}(lb::VecOrNothing{T}, ub::VecOrNothing{T}, n::Int)
    has_lb = false
    has_ub = false
    if ! _jl_glpk__is_empty(lb)
        if size(lb, 1) != n
            error("invlid lb size: $(size(lb))")
        end
        has_lb = true
    end
    if ! _jl_glpk__is_empty(ub)
        if size(ub, 1) != n
            error("invalid ub size: $(size(ub))")
        end
        has_ub = true
    end
    return (has_lb, has_ub)
end

function _jl_linprog__dense_matrices_to_glp_format(m, meq, n, A, Aeq)
    l = (m + meq) * n

    ia = zeros(Int32, l)
    ja = zeros(Int32, l)
    ar = zeros(Float64, l)

    k = 0
    for r = 1 : m
        for c = 1 : n
            k += 1
            ia[k] = r
            ja[k] = c
            ar[k] = A[r, c]
        end
    end
    for r = 1 : meq
        for c = 1 : n
            r0 = r + m
            k += 1
            ia[k] = r0
            ja[k] = c
            ar[k] = Aeq[r, c]
        end
    end
    return (ia, ja, ar)
end
