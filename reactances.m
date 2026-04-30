mpc = case24_ieee_rts;

is_line = (mpc.branch(:,9) == 0);   % transmission lines only
line_rows = find(is_line);          % original branch row numbers
x_lines = abs(mpc.branch(is_line,4));

for k = 1:length(line_rows)
    r = line_rows(k);
    fprintf('x_lines(%2d) = %.4f  -> branch row %2d : bus %2d to bus %2d\n', ...
        k, x_lines(k), r, mpc.branch(r,1), mpc.branch(r,2));
end