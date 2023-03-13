classdef BeginDay < handle
    properties
        Time;
    end
    methods
        function obj = BeginDay(Time)
            arguments
                Time = 0.0;
            end
            obj.Time = Time;
        end
        function varargout = visit(obj, other)
            [varargout{1:nargout}] = handle_begin_day(other, obj);
        end
    end
end