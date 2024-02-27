classdef OutgoingOrder < Event
    properties (SetAccess = public)
        Amount = 1;
        OriginalTime = 0;
    end
    methods
        function obj = OutgoingOrder(KWArgs)
            % OutgoingOrder constructor.
            % Public properties can be specified as named arguments.
            arguments
                KWArgs.?OutgoingOrder;
            end
            fnames = fieldnames(KWArgs);
            for ifield=1:length(fnames)
                s = fnames{ifield};
                obj.(s) = KWArgs.(s);
            end
        end
        function new = reschedule(obj, Time)
            new = copy(obj);
            new.Time = Time;
        end
        function varargout = visit(obj, other)
            [varargout{1:nargout}] = handle_outgoing_order(other, obj);
        end
    end
end