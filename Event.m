classdef (Abstract=true) Event < handle
    % Event Abstract base class for all events.

    properties
        % Time - Time at which this event happens
        Time = 0;
    end

    methods
        function obj = Event(KWArgs)
            % Event Constructor.
            % Public properties can be specified as named arguments.
            arguments
                KWArgs.?Event;
            end
            fnames = fieldnames(KWArgs);
            for ifield=1:length(fnames)
                s = fnames{ifield};
                obj.(s) = KWArgs.(s);
            end
        end
    end
    methods (Abstract=true)
        % visit - Call a handle_??? event on a target object, passing self
        visit(obj, target)
    end
end