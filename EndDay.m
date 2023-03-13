classdef EndDay < handle
    properties
        Time;
    end
    methods
        function obj = EndDay(Time)
            arguments
                Time = 0.0;
            end
            obj.Time = Time;
        end
        function varargout = visit(obj, other)
            [varargout{1:nargout}] = handle_end_day(other, obj);
        end
    end
end