classdef BeginDay < Event
    % BeginDay An event representing the beginning of a day.
    methods
        function varargout = visit(obj, other)
            % visit Call handle_begin_day.
            [varargout{1:nargout}] = handle_begin_day(other, obj);
        end
    end
end