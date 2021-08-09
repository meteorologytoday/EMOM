classdef Tunnel < handle
    properties
        fns
        next_ptr
    end
    methods
        function self = Tunnel(path, name)
            self.fns = string.empty;
            for i = 1 : 2
                self.fns(i) = fullfile(path, sprintf('_%s_%d.fifo', name, i));
            end
            self.next_ptr = 1;
        end

        function  fn = getTunnelFilename(self)
            next_ptr = self.next_ptr;
            self.next_ptr = mod(next_ptr, length(self.fns)) + 1;
            fn = self.fns(next_ptr);
        end

    end
end
