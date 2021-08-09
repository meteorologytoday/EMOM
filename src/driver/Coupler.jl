mutable struct Coupler
    OMMODULE  :: Any
    OMDATA    :: Any 

    init!       :: Function
    before_run! :: Function
    after_run!  :: Function 
    final!      :: Function
end
