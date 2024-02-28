classdef EndDay < Event
    % EndDay An event representing the end of a day.
    methods
        function varargout = visit(obj, other)
            % visit Call handle_end_day
            [varargout{1:nargout}] = handle_end_day(other, obj);
        end
    end
end