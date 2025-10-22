import Link from "next/link";
import {
  Card,
  CardAction,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@workspace/ui/components/card";
import { Button } from "@workspace/ui/components/button";
import { Badge } from "@workspace/ui/components/badge";
import { formatPrice } from "../lib/utils";

type ProductCardProps = {
  name: string;
  price: number;
  inStock: boolean;
  slug: string;
};

export function ProductCard({ name, price, inStock, slug }: ProductCardProps) {
  return (
    <Card>
      <CardHeader>
        <CardTitle>{name}</CardTitle>
        <CardDescription>{formatPrice(price)}</CardDescription>
        <CardAction>
          <Button variant="ghost" size="icon-sm">
            ♡
          </Button>
        </CardAction>
      </CardHeader>
      <CardContent>
        <div className="flex items-center gap-2">
          <Badge variant={inStock ? "secondary" : "outline"}>
            {inStock ? "In Stock" : "Out of Stock"}
          </Badge>
        </div>
      </CardContent>
      <CardFooter className="flex-col gap-2">
        <Button className="w-full" disabled={!inStock}>
          Add to Cart
        </Button>
        <Button variant="outline" className="w-full" asChild>
          <Link href={`/products/${slug}`}>View Details</Link>
        </Button>
      </CardFooter>
    </Card>
  );
}
