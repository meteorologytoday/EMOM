classdef TunnelSet < handle
    properties
        tnls
    end
    methods
        function self = TunnelSet(path, recv_txt, send_txt, recv_bin, send_bin)
            self.tnls = containers.Map;
            self.tnls('recv_txt') = Tunnel(path, recv_txt);
            self.tnls('send_txt') = Tunnel(path, send_txt);
            self.tnls('recv_bin') = Tunnel(path, recv_bin);
            self.tnls('send_bin') = Tunnel(path, send_bin);
        end


        function mkTunnel(self)

            for k = keys(self.tnls)
                tnl = self.tnls(k{1})
                for i = 1:length(tnl.fns)
                    system(sprintf('%s %s', 'mkfifo ', tnl.fns(i)))
                end
            end
        end

        function reverseRole(self)
            [self.tnls('recv_txt'), self.tnls('send_txt')] = swap(self.tnls('recv_txt'), self.tnls('send_txt'));
            [self.tnls('recv_bin'), self.tnls('send_bin')] = swap(self.tnls('recv_bin'), self.tnls('send_bin'));
        end

        function fn = getTunnelFilename(self, key)
            tnl = self.tnls(key);
            fn = tnl.getTunnelFilename();
        end

        function msg = recvText(self)
            fd = fopen(self.getTunnelFilename('recv_txt'), 'r');
            %msg = self.parse(fscanf(fd, '%s'));

            msg = fscanf(fd, '%s');

            fclose(fd);
        end 

        function sendText(self, msg)
            fd = fopen(self.getTunnelFilename('send_txt'), 'w');
            fwrite(fd, msg);
            fclose(fd);
        end

        function data = recvBinary(self, n)
            fd = fopen(self.getTunnelFilename('recv_bin'), 'r');
            data = fread(fd, n, 'double=>double', 'ieee-le');
            fclose(fd); 
        end

        function sendBinary(self, arr)
            fd = fopen(self.getTunnelFilename('send_bin'), 'w');
            fwrite(fd, arr, 'double', 'ieee-le');
            fclose(fd); 
        end



        function obj = parse(self, msg)
            obj = containers.Map
            pieces = split(msg, ';')
            for i = 1 : length(pieces)
                kvpair = split(pieces(i), ':')
                if length(kvpair) == 2
                    obj(char(kvpair(1))) = char(kvpair(2))
                end
            end
        end


    end
end


