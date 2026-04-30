function a = smcs_row(T, lambda, mu)
% Generates availability (1=up, 0=down) for one component

    a = ones(1, T);
    t = 1;
    state = 1;   % start in service

    while t <= T
        if state == 1
            up_time = max(1, ceil(-log(rand)/lambda));
            a(t:min(T, t+up_time-1)) = 1;
            t = t + up_time;
            state = 0;
        else
            down_time = max(1, ceil(-log(rand)/mu));
            a(t:min(T, t+down_time-1)) = 0;
            t = t + down_time;
            state = 1;
        end
    end
end