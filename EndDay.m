classdef EndDay < Event
    methods
        function varargout = visit(obj, other)
            [varargout{1:nargout}] = handle_end_day(other, obj);
        end
    end
end